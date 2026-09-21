//
//  NotificationService.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import OSLog
import UserNotifications

/// Push action identifiers. Pulled out of string literals so that registering
/// the category and parsing the response in AppDelegate cannot drift apart.
enum NotificationAction {
    static let take = "ACTION_TAKE"
    static let snooze = "ACTION_SNOOZE"
    static let skip = "ACTION_SKIP"
}

/// Orchestration, and only that.
///
/// The three jobs live where each can be reasoned about separately:
/// `ReminderPlanner` decides what the queue should contain,
/// `ReminderRequestFactory` builds the requests, and `NotificationCenterClient`
/// is the one thing that talks to iOS. What is left here is the sequencing —
/// which read comes before which write, and what must not overlap with what.
///
/// Explicit `@MainActor`, though the module already builds with
/// SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor: this type reads SwiftData models
/// and keeps `rescheduleTask`, and neither should silently lose its isolation if
/// that build setting ever changes.
@MainActor
final class NotificationService: NotificationServiceProtocol {

    private let center: any NotificationCenterClient

    /// The most recently started rebuild. See `rescheduleAll`.
    private var rescheduleTask: Task<Void, Never>?

    // MARK: - Init

    init(center: any NotificationCenterClient) {
        self.center = center

        // The categories are registered when the service is created, not only
        // inside requestPermission: on a second launch permission is already
        // granted, the authorization callback may never reach registration, and
        // reminders would arrive without their buttons.
        center.setCategories(ReminderRequestFactory.categories())
    }

    /// The app's service, talking to the real notification centre.
    ///
    /// A separate initialiser rather than a default argument on the one above:
    /// a default argument is evaluated at the CALL SITE, outside this type's
    /// main-actor isolation, so naming a main-actor-isolated initialiser there
    /// does not compile. Here the call is plainly inside it.
    convenience init() {
        self.init(center: SystemNotificationCenterClient())
    }

    // MARK: - Permission

    /// Returns whether notifications are allowed, so the caller can react — the
    /// callback version threw the answer away and the diary reminder was armed
    /// even when the user had just refused.
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if !granted {
                AppLog.notifications.info("Notifications declined by user")
            }
            return granted
        } catch {
            AppLog.notifications.error("Permission request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Full rebuild

    /// Clears the queue and refills it from the unfinished courses.
    ///
    /// Rebuilds are chained rather than run in parallel. Every call site is a
    /// `Task { }` started from a synchronous closure — saving an edit, logging a
    /// dose, the scene becoming active — so two of them overlapping is the normal
    /// case, not the exception. Overlapping is what breaks: B's clear can land
    /// between A's clear and A's adds, both sets then survive, and the user gets
    /// every reminder twice.
    func rescheduleAll(using dbService: any CourseStoring) async {
        // Read and reassigned with no await in between, so on the main actor this
        // is atomic: whoever comes next chains onto this task, not onto the one it
        // replaced.
        let previous = rescheduleTask
        let task = Task { [weak self] in
            _ = await previous?.value
            guard let self else { return }

            await self.removeAllPending()
            await self.scheduleNotifications(activeCourses: self.activeCourses(from: dbService))
        }
        rescheduleTask = task
        await task.value
    }

    /// Single entry point for clearing all scheduled notifications, so callers
    /// don't reach into the notification centre directly.
    func removeAllPending() async {
        await center.removeAllPending()

        // The daily reminders are not part of the course schedule but share the
        // queue, so a course edit would silently take them down with everything
        // else. Re-armed here rather than at the call sites of rescheduleAll,
        // where forgetting it once is enough to lose them.
        await restoreDailyRemindersIfEnabled()
    }

    // MARK: - Scheduling

    func scheduleNotifications(activeCourses: [TreatmentCourse]) async {
        let calendar = Calendar.current
        let scheduleMap = ReminderPlanner.buildScheduleMap(
            activeCourses: activeCourses, now: Date(), calendar: calendar
        )

        // Sorted by trigger date so that, if the count exceeds iOS's limit, it is
        // the soonest reminders that get scheduled rather than an arbitrary
        // Dictionary iteration order.
        let sortedEntries = scheduleMap.sorted { $0.key < $1.key }

        // Every request is built before anything is sent, while the SwiftData
        // objects behind them are still in hand.
        var requests: [UNNotificationRequest] = []
        for (triggerDate, medsAtTime) in sortedEntries {
            guard requests.count < ReminderPlanner.maxScheduled else { break }

            requests.append(
                ReminderRequestFactory.doseReminder(
                    medicationIds: medsAtTime.map { $0.medication.id.uuidString },
                    medicationNames: medsAtTime.map { $0.medication.name },
                    triggerDate: triggerDate,
                    calendar: calendar
                )
            )
        }

        if sortedEntries.count > requests.count {
            AppLog.notifications.warning("Slots beyond the iOS limit were not scheduled: \(sortedEntries.count - requests.count)")
        }

        // How far ahead the user is actually covered. Worth having in the log: it
        // is the number that says whether someone who stops opening the app keeps
        // getting reminded, and it moves with how many medications they take.
        if let lastCovered = sortedEntries.prefix(requests.count).last?.key {
            let days = calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: Date()), to: lastCovered
            ).day ?? 0
            AppLog.notifications.debug("Reminders cover the next \(days) day(s)")
        }

        await add(requests, failureMessage: "Failed to schedule")
        AppLog.notifications.debug("Grouped and scheduled notifications: \(requests.count)")
    }

    // MARK: - Snooze

    func scheduleSnooze(for medicationIds: [String], names: [String]) async {
        guard !medicationIds.isEmpty else { return }

        await add(
            [ReminderRequestFactory.snooze(medicationIds: medicationIds, names: names)],
            failureMessage: "Snooze failed"
        )
    }

    // MARK: - Cancellation

    /// Stops reminding about one medication — it was deleted, or its course was.
    ///
    /// The decisions are `ReminderPlanner.cancellationPlan`; this reads the queue,
    /// hands it over, and carries the answer out in order: removals first, then the
    /// rebuilt groups, so a regrouped reminder is never removed straight after
    /// being added.
    func cancelNotifications(for medicationId: UUID) async {
        let plan = ReminderPlanner.cancellationPlan(
            forMedication: medicationId,
            pending: await center.pendingReminders(),
            delivered: await center.deliveredReminders()
        )
        guard !plan.isEmpty else { return }

        center.removeDelivered(identifiers: plan.deliveredToRemove)
        if !plan.deliveredToRemove.isEmpty {
            AppLog.notifications.debug("Removed from lock screen: \(plan.deliveredToRemove.count)")
        }

        center.removePending(identifiers: plan.pendingToRemove)
        if !plan.pendingToRemove.isEmpty {
            AppLog.notifications.debug("Cancelled pending notifications: \(plan.pendingToRemove.count)")
        }

        let replacements = plan.regrouped.map { group in
            ReminderRequestFactory.doseReminder(
                identifier: group.identifier,
                medicationIds: group.medicationIds,
                medicationNames: group.medicationNames,
                triggerDate: group.triggerDate,
                trigger: group.trigger
            )
        }
        await add(replacements, failureMessage: "Regroup failed")
    }

    // MARK: - Delivered cleanup

    func clearDelivered(settledMedicationIds: [UUID], scheduledTime: Date) async {
        guard !settledMedicationIds.isEmpty else { return }

        let toRemove = ReminderPlanner.deliveredToClear(
            settledMedicationIds: Set(settledMedicationIds.map(\.uuidString)),
            slot: scheduledTime,
            delivered: await center.deliveredReminders()
        )

        guard !toRemove.isEmpty else { return }
        center.removeDelivered(identifiers: toRemove)
        AppLog.notifications.debug("Removed delivered reminders for a fully logged slot: \(toRemove.count)")
    }

    // MARK: - Daily reminders

    func scheduleDailyReminder(_ reminder: DailyReminder, minutesOfDay: [Int]) async {
        // Every identifier the reminder could hold, not just the ones about to be
        // used: dropping from three times to two has to take the third request
        // with it, or it keeps firing at a time the user removed.
        center.removePending(identifiers: reminder.allRequestIdentifiers)

        let times = Array(minutesOfDay.prefix(reminder.maxTimes))
        let requests = times.enumerated().map { index, minuteOfDay in
            ReminderRequestFactory.dailyReminder(reminder, minuteOfDay: minuteOfDay, index: index)
        }

        await add(requests, failureMessage: "Daily reminder failed")
    }

    /// Stays synchronous: a removal by identifier has nothing to wait for, and no
    /// caller needs to know when the daemon got round to it.
    func cancelDailyReminder(_ reminder: DailyReminder) {
        center.removePending(identifiers: reminder.allRequestIdentifiers)
    }

    private func restoreDailyRemindersIfEnabled() async {
        for reminder in DailyReminder.allCases where reminder.isEnabled {
            await scheduleDailyReminder(reminder, minutesOfDay: reminder.minutesOfDay)
        }
    }

    // MARK: - Adding

    /// One place where a failed add is logged rather than thrown away silently.
    /// A reminder that does not get queued is the failure this app cannot afford,
    /// so it is worth the same line every time.
    private func add(_ requests: [UNNotificationRequest], failureMessage: String) async {
        for request in requests {
            do {
                try await center.add(request)
            } catch {
                AppLog.notifications.error("\(failureMessage, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
