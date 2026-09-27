//
//  NotificationService.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import OSLog
import UserNotifications

// MARK: - NotificationAction

/// Notification action identifiers shared by category registration and response parsing.
enum NotificationAction {
    static let take = "ACTION_TAKE"
    static let snooze = "ACTION_SNOOZE"
    static let skip = "ACTION_SKIP"
}

// MARK: - NotificationService

/// Sequences reminder work: planning is `ReminderPlanner`, building is
/// `ReminderRequestFactory`, and iOS access is `NotificationCenterClient`.
/// Explicit `@MainActor`: it reads SwiftData models and guards `queueTail`.
@MainActor
final class NotificationService: NotificationServiceProtocol {

    // MARK: - Properties

    private let center: any NotificationCenterClient

    /// Source of daily reminder on/off and times when the queue is rebuilt.
    private let settings: SettingsStore

    private let time: any TimeSource

    /// The last operation queued through `serialized`.
    private var queueTail: Task<Void, Never>?

    // MARK: - Init

    init(center: any NotificationCenterClient, settings: SettingsStore, time: any TimeSource = SystemTime()) {
        self.time = time
        self.center = center
        self.settings = settings

        // Registered here, not only on permission request, or later launches get buttonless reminders.
        center.setCategories(ReminderRequestFactory.categories())
    }

    /// Uses the real notification centre. Not a default argument: those are evaluated
    /// at the call site, outside main-actor isolation, and would not compile.
    convenience init(settings: SettingsStore, time: any TimeSource) {
        self.init(center: SystemNotificationCenterClient(), settings: settings, time: time)
    }

    // MARK: - Permission

    /// Whether notifications are allowed.
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

    // MARK: - Full Rebuild

    /// Clears the queue and refills it from active courses. Serialized: overlapping
    /// rebuilds interleave clears and adds and duplicate every reminder.
    func rescheduleAll(using dbService: any CourseStoring) async {
        await serialized { [weak self] in
            guard let self else { return }
            let allCourses = dbService.fetchAllCourses()
            let courses = allCourses.filter { $0.isActive(on: self.time.now, calendar: self.time.calendar) }
            await self.clearForRebuild(courses: allCourses)
            await self.scheduleNotifications(activeCourses: courses)
            await self.scheduleRefillReminder(activeCourses: courses)
            // Every dose write, course change and app activation ends up here.
            await self.center.setBadgeCount(
                DoseBadge.count(courses: courses, at: self.time.now, calendar: self.time.calendar)
            )
        }
    }

    /// Runs `work` after everything queued before it, so rebuilds and cancellations
    /// never interleave. No await between reading and reassigning `queueTail`: keep it atomic.
    private func serialized(_ work: @escaping () async -> Void) async {
        let previous = queueTail
        let task = Task {
            _ = await previous?.value
            await work()
        }
        queueTail = task
        await task.value
    }

    /// Clears the queue except snoozes whose doses are still open: the user was
    /// promised those. Snoozes of doses logged since are dropped with the rest.
    private func clearForRebuild(courses: [TreatmentCourse]) async {
        let pending = await center.pendingReminders()
        let keep = ReminderPlanner.snoozesToKeep(pending: pending, courses: courses, calendar: time.calendar)

        center.removePending(identifiers: pending.map(\.identifier).filter { !keep.contains($0) })
        // The centre runs calls in order, so this read waits for the removal.
        _ = await center.pendingReminders()

        await restoreDailyRemindersIfEnabled()
    }

    func removeAllPending() async {
        await center.removeAllPending()

        // Daily reminders share the queue, so they are re-armed after every clear.
        await restoreDailyRemindersIfEnabled()
    }

    // MARK: - Scheduling

    func scheduleNotifications(activeCourses: [TreatmentCourse]) async {
        let calendar = time.calendar
        let scheduleMap = ReminderPlanner.buildScheduleMap(
            activeCourses: activeCourses, now: time.now, calendar: calendar
        )

        // Soonest first, so the iOS limit drops the furthest reminders.
        let sortedEntries = scheduleMap.sorted { $0.key < $1.key }

        let scheduled = sortedEntries.prefix(ReminderPlanner.maxScheduled)
        // Each reminder sets the icon to what will be open when it fires.
        let badges = DoseBadge.counts(at: scheduled.map(\.key), courses: activeCourses, calendar: calendar)

        // Build all requests before any await, while the SwiftData objects are in hand.
        let requests = scheduled.map { triggerDate, medsAtTime in
            ReminderRequestFactory.doseReminder(
                medicationIds: medsAtTime.map { $0.medication.id.uuidString },
                medicationNames: medsAtTime.map { $0.medication.name },
                triggerDate: triggerDate,
                calendar: calendar,
                badge: badges[triggerDate]
            )
        }

        if sortedEntries.count > requests.count {
            AppLog.notifications.warning("Slots beyond the iOS limit were not scheduled: \(sortedEntries.count - requests.count)")
        }

        if let lastCovered = sortedEntries.prefix(requests.count).last?.key {
            let days = calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: time.now), to: lastCovered
            ).day ?? 0
            AppLog.notifications.debug("Reminders cover the next \(days) day(s)")
        }

        await add(requests, failureMessage: "Failed to schedule")
        AppLog.notifications.debug("Grouped and scheduled notifications: \(requests.count)")
    }

    // MARK: - Refill

    /// Runs inside the rebuild, after the queue was cleared, so it never piles up.
    private func scheduleRefillReminder(activeCourses: [TreatmentCourse]) async {
        guard settings.isRefillReminderEnabled,
              let plan = RefillReminder.plan(
                activeCourses: activeCourses,
                minuteOfDay: settings.refillReminderMinuteOfDay,
                now: time.now,
                calendar: time.calendar
              )
        else { return }

        await add(
            [ReminderRequestFactory.refillReminder(plan, calendar: time.calendar)],
            failureMessage: "Refill reminder failed"
        )
    }

    // MARK: - Snooze

    func scheduleSnooze(for medicationIds: [String], names: [String], slot: Date) async {
        guard !medicationIds.isEmpty else { return }

        await add(
            [ReminderRequestFactory.snooze(medicationIds: medicationIds, names: names, slot: slot)],
            failureMessage: "Snooze failed"
        )
    }

    // MARK: - Cancellation

    /// Stops reminding about one medication. Removals run before re-adding
    /// regrouped requests, so a regrouped reminder is never removed right after adding.
    func cancelNotifications(for medicationId: UUID) async {
        await serialized { [weak self] in
            await self?.performCancellation(for: medicationId)
        }
    }

    private func performCancellation(for medicationId: UUID) async {
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

    // MARK: - Delivered Cleanup

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

    // MARK: - Daily Reminders

    func scheduleDailyReminder(_ reminder: DailyReminder, minutesOfDay: [Int]) async {
        // All slots, so a removed time stops firing too.
        center.removePending(identifiers: reminder.allRequestIdentifiers)

        let times = Array(minutesOfDay.prefix(reminder.maxTimes))
        let requests = times.enumerated().map { index, minuteOfDay in
            ReminderRequestFactory.dailyReminder(reminder, minuteOfDay: minuteOfDay, index: index)
        }

        await add(requests, failureMessage: "Daily reminder failed")
    }

    func cancelDailyReminder(_ reminder: DailyReminder) {
        center.removePending(identifiers: reminder.allRequestIdentifiers)
    }

    private func restoreDailyRemindersIfEnabled() async {
        for reminder in DailyReminder.allCases where settings.isEnabled(reminder) {
            await scheduleDailyReminder(reminder, minutesOfDay: settings.minutesOfDay(for: reminder))
        }
    }

    // MARK: - Adding

    /// Adds each request, logging (never silently dropping) any failure.
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
