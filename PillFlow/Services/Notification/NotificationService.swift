//
//  NotificationService.swift
//  PillFlow
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

/// Explicit, though the module already builds with SWIFT_DEFAULT_ACTOR_ISOLATION
/// = MainActor: this type reads SwiftData models and keeps `rescheduleTask`, and
/// neither should silently lose its isolation if that build setting ever changes.
@MainActor
final class NotificationService: NotificationServiceProtocol {

    /// Single source of truth for the snooze delay, so the category action's
    /// title and the actual scheduled trigger can't drift out of sync.
    private static let snoozeInterval: TimeInterval = 15 * 60

    private static let categoryIdentifier = "PILL_REMINDER_CATEGORY"

    /// How many requests the dose schedule may occupy.
    ///
    /// iOS keeps at most 64 pending local notifications per app and silently drops
    /// the rest, and the dose schedule is not the only thing in that queue: the
    /// daily reminders hold one slot per time, permanently — up to four between
    /// them — and a snooze takes one per group.
    /// The horizon below now stretches until this budget is spent, so the ceiling
    /// is reached in normal use rather than in theory — the headroom has to be
    /// real.
    ///
    /// `nonisolated` because it is the default argument of `buildScheduleMap`,
    /// and a default argument is evaluated at the call site — outside this type's
    /// main-actor isolation. Safe: an immutable Int carries no state to race over.
    nonisolated static let maxScheduled = 56

    /// Hard stop for the day-by-day walk, so a course with a very rare frequency
    /// (or a corrupt end date) cannot spin. Reached only when the budget never
    /// fills up.
    nonisolated static let maxHorizonDays = 365

    /// The most recently started rebuild. See `rescheduleAll`.
    private var rescheduleTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        // The category is registered when the service is created, not only inside
        // requestPermission: on a second launch permission is already granted, the
        // authorization callback may never reach registration, and reminders would
        // arrive without their buttons.
        registerNotificationCategories()
    }

    // MARK: - Notification Categories

    private func registerNotificationCategories() {
        let center = UNUserNotificationCenter.current()

        let takeAction = UNNotificationAction(
            identifier: NotificationAction.take,
            title: "Take Now",
            options: .foreground
        )
        let snoozeAction = UNNotificationAction(
            identifier: NotificationAction.snooze,
            title: "Snooze 15m",
            options: []
        )
        let skipAction = UNNotificationAction(
            identifier: NotificationAction.skip,
            title: "Skip",
            options: .destructive
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [takeAction, snoozeAction, skipAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // One per daily reminder: the dose actions (Take, Snooze, Skip) make no
        // sense on them, and a shared category would put those actions on every
        // reminder the app ever adds.
        let reminderCategories = DailyReminder.allCases.map { reminder in
            UNNotificationCategory(
                identifier: reminder.categoryIdentifier,
                actions: [],
                intentIdentifiers: [],
                options: .customDismissAction
            )
        }

        center.setNotificationCategories(Set([category] + reminderCategories))
    }

    // MARK: - Permission

    /// Returns whether notifications are allowed, so the caller can react — the
    /// callback version threw the answer away and the diary reminder was armed
    /// even when the user had just refused.
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
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
    func rescheduleAll(using dbService: DatabaseServiceProtocol) async {
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
    /// don't reach into UNUserNotificationCenter directly.
    ///
    /// Does not return until the removal has actually been carried out — see
    /// `waitForPendingRemoval`. Everything downstream depends on that: scheduling
    /// straight after a removal that is still in flight is how a whole rebuild
    /// used to get wiped.
    func removeAllPending() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        await waitForPendingRemoval()

        // The daily reminders are not part of the course schedule but share the
        // queue, so a course edit would silently take them down with everything
        // else. Re-armed here rather than at the call sites of rescheduleAll,
        // where forgetting it once is enough to lose them.
        await restoreDailyRemindersIfEnabled()
    }

    /// Waits for everything already queued on the notification centre to be
    /// processed.
    ///
    /// `removeAllPendingNotificationRequests()` is asynchronous: it returns at once
    /// and the removal happens later, on the centre's own queue. The centre handles
    /// calls in order, so a read issued after the removal only comes back once the
    /// removal is done — which is all this is for.
    private func waitForPendingRemoval() async {
        _ = await UNUserNotificationCenter.current().pendingNotificationRequests()
    }

    // MARK: - Daily reminders

    func scheduleDailyReminder(_ reminder: DailyReminder, minutesOfDay: [Int]) async {
        let center = UNUserNotificationCenter.current()

        // Every identifier the reminder could hold, not just the ones about to be
        // used: dropping from three times to two has to take the third request
        // with it, or it keeps firing at a time the user removed.
        center.removePendingNotificationRequests(withIdentifiers: reminder.allRequestIdentifiers)

        let times = Array(minutesOfDay.prefix(reminder.maxTimes))

        for (index, minuteOfDay) in times.enumerated() {
            let (hour, minute) = DailyReminder.hourAndMinute(from: minuteOfDay)
            var components = DateComponents()
            components.hour = hour
            components.minute = minute

            let content = UNMutableNotificationContent()
            content.title = reminder.notificationTitle
            content.body = reminder.notificationBody
            content.sound = .default
            content.categoryIdentifier = reminder.categoryIdentifier
            // What tells AppDelegate which screen to open. The dose branch keys
            // off medicationIds, which these deliberately do not carry.
            content.userInfo = [DailyReminder.userInfoKey: reminder.rawValue]

            // repeats: true — a daily reminder is not tied to a course and needs
            // no per-day skipping, so one request covers every day for ever. It
            // is also why each time costs exactly one slot of the 64 iOS allows,
            // however far ahead the dose schedule reaches.
            let request = UNNotificationRequest(
                identifier: reminder.requestIdentifier(at: index),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )

            do {
                try await center.add(request)
            } catch {
                AppLog.notifications.error("Daily reminder failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Stays synchronous: a removal by identifier has nothing to wait for, and no
    /// caller needs to know when the daemon got round to it.
    func cancelDailyReminder(_ reminder: DailyReminder) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: reminder.allRequestIdentifiers)
    }

    private func restoreDailyRemindersIfEnabled() async {
        for reminder in DailyReminder.allCases where reminder.isEnabled {
            await scheduleDailyReminder(reminder, minutesOfDay: reminder.minutesOfDay)
        }
    }

    // MARK: - Request building

    /// Request building in one place: initial scheduling and regrouping after one
    /// medication is cancelled both go through here, so the text and the userInfo
    /// payload cannot diverge.
    private static func makeReminderRequest(
        identifier: String,
        medicationIds: [String],
        medicationNames: [String],
        triggerDate: Date,
        trigger: UNNotificationTrigger
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "💊 Time to take your meds")
        // Foundation builds the list: the separator and the conjunction before the
        // last item differ from language to language.
        let names = medicationNames.formatted(.list(type: .and))
        content.body = String(localized: "Time to take: \(names)")
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [
            "medicationIds": medicationIds,
            // Names are needed to rebuild a group reminder without one medication, and
            // so a snoozed notification still knows what it is reminding about.
            "medicationNames": medicationNames,
            "time": triggerDate.timeIntervalSince1970
        ]
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private static func medicationIds(in content: UNNotificationContent) -> [String] {
        content.userInfo["medicationIds"] as? [String] ?? []
    }

    private static func medicationNames(in content: UNNotificationContent) -> [String] {
        content.userInfo["medicationNames"] as? [String] ?? []
    }

    /// One single way to build a snooze identifier. It used to be scheduled under
    /// `SNOOZE_<all ids joined by _>` but cancelled under `SNOOZE_<one id>`, so a
    /// group snooze could never be cancelled.
    private static func snoozeIdentifier(for medicationIds: [String]) -> String {
        "SNOOZE_" + medicationIds.sorted().joined(separator: "_")
    }

    // MARK: - Delivered cleanup

    /// Removes an already delivered notification for the `scheduledTime` slot, but
    /// only when EVERY medication in that group is marked taken.
    ///
    /// One notification can cover several medications at once (see
    /// `buildScheduleMap` — slots are grouped by time). While any medication in the
    /// group is untaken the reminder is still valid, so only fully closed slots
    /// are removed.
    func clearDelivered(takenMedicationIds: [UUID], scheduledTime: Date) async {
        guard !takenMedicationIds.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        let takenIds = Set(takenMedicationIds.map { $0.uuidString })
        let slot = scheduledTime.timeIntervalSince1970

        let delivered = await center.deliveredNotifications()
        let toRemove = delivered.compactMap { notif -> String? in
            let ids = Self.medicationIds(in: notif.request.content)
            guard !ids.isEmpty,
                  let time = notif.request.content.userInfo["time"] as? TimeInterval,
                  // Both dates are built the same way, but a Double round-tripped
                  // through userInfo should not be compared exactly — allow a
                  // second of drift.
                  abs(time - slot) < 1,
                  Set(ids).isSubset(of: takenIds)
            else { return nil }
            return notif.request.identifier
        }

        guard !toRemove.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: toRemove)
        AppLog.notifications.debug("Removed delivered reminders for a fully logged slot: \(toRemove.count)")
    }

    /// One medication flattened into everything the day walk needs.
    ///
    /// Prepared once per rebuild so the walk never touches a SwiftData
    /// relationship or rescans `logs` for each day it considers. That rescan was
    /// affordable while the horizon was three days; over weeks it is the
    /// difference between hundreds of comparisons and hundreds of thousands.
    private struct MedicationPlan {
        let courseName: String
        let medication: MedicationItem
        let startDay: Date
        let endDay: Date
        let frequencyDays: Int
        let times: [(hour: Int, minute: Int)]
        /// Slots already logged as taken, keyed the way a trigger date is keyed.
        let takenSlots: Set<DateComponents>
    }

    private static let slotUnits: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]

    // MARK: - Schedule Building

    /// Pure, side-effect-free computation of what needs to be scheduled, kept
    /// separate from scheduleNotifications so its rules can be unit tested without
    /// a real notification centre. `now`/`calendar` default to live values so
    /// production behaviour is unaffected; tests inject fixed ones.
    ///
    /// Three rules live here. Medications that share a trigger time are grouped
    /// into a single push. Slots already logged as taken are skipped, so a dose
    /// logged in advance doesn't still ring. And the horizon runs as far ahead as
    /// `slotBudget` allows instead of a fixed three days: nothing re-plans the
    /// schedule while the app is closed, so the old window meant a course going
    /// quiet on the fourth day the user didn't open the app — the one failure this
    /// app cannot afford.
    static func buildScheduleMap(
        activeCourses: [TreatmentCourse],
        now: Date = Date(),
        calendar: Calendar = .current,
        slotBudget: Int = maxScheduled,
        horizonLimitInDays: Int = maxHorizonDays
    ) -> [Date: [(courseName: String, medication: MedicationItem)]] {

        let today = calendar.startOfDay(for: now)

        let plans: [MedicationPlan] = activeCourses.flatMap { course in
            course.medications.compactMap { med -> MedicationPlan? in
                // The dose-day step is frequencyDays. At zero every day would match
                // and the medication would be scheduled at every slot. Unreachable
                // from the UI (the picker offers 1/2/3/7/14/30), but data can arrive
                // from a migration or an import.
                guard med.frequencyDays > 0 else { return nil }

                let times = med.timesOfDay.map { time -> (hour: Int, minute: Int) in
                    let parts = calendar.dateComponents([.hour, .minute], from: time)
                    return (parts.hour ?? 0, parts.minute ?? 0)
                }

                let taken = Set(
                    med.logs
                        .filter(\.isTaken)
                        .map { calendar.dateComponents(Self.slotUnits, from: $0.scheduledTime) }
                )

                return MedicationPlan(
                    courseName: course.name,
                    medication: med,
                    startDay: calendar.startOfDay(for: course.startDate),
                    endDay: calendar.startOfDay(for: course.endDate),
                    frequencyDays: med.frequencyDays,
                    times: times,
                    takenSlots: taken
                )
            }
        }

        guard !plans.isEmpty else { return [:] }

        var scheduleMap: [Date: [(courseName: String, medication: MedicationItem)]] = [:]

        // Driven by the day rather than by each medication's own stepping: a day is
        // the unit the budget is spent in, and asking "is this a dose day" with one
        // modulo replaces walking a course forward from a start date months back.
        for dayOffset in 0..<horizonLimitInDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { break }

            // Every course is over; nothing further out can match.
            if plans.allSatisfy({ $0.endDay < day }) { break }

            var slotsForDay: [Date: [(courseName: String, medication: MedicationItem)]] = [:]

            for plan in plans {
                guard day >= plan.startDay, day <= plan.endDay else { continue }

                let daysSinceStart = calendar.dateComponents([.day], from: plan.startDay, to: day).day ?? 0
                guard daysSinceStart % plan.frequencyDays == 0 else { continue }

                for time in plan.times {
                    guard let triggerDate = calendar.date(
                        bySettingHour: time.hour, minute: time.minute, second: 0, of: day
                    ), triggerDate > now else { continue }

                    let slot = calendar.dateComponents(Self.slotUnits, from: triggerDate)
                    guard !plan.takenSlots.contains(slot) else { continue }

                    slotsForDay[triggerDate, default: []].append(
                        (courseName: plan.courseName, medication: plan.medication)
                    )
                }
            }

            guard !slotsForDay.isEmpty else { continue }

            // Whole days only. Half a day inside the budget would give the user the
            // 08:00 reminder and not the 20:00 one, which reads as the app losing
            // doses rather than as a horizon. The exception is a first day that
            // fills the budget on its own — covering it partly still beats covering
            // nothing, and scheduleNotifications trims by time from there.
            if !scheduleMap.isEmpty, scheduleMap.count + slotsForDay.count > slotBudget { break }

            scheduleMap.merge(slotsForDay) { current, _ in current }

            if scheduleMap.count >= slotBudget { break }
        }

        return scheduleMap
    }

    // MARK: - Scheduling

    func scheduleNotifications(activeCourses: [TreatmentCourse]) async {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current

        let scheduleMap = Self.buildScheduleMap(activeCourses: activeCourses, now: Date(), calendar: calendar)

        // Sort by trigger date so that, if the count exceeds iOS's notification
        // limit, it's the soonest reminders that get scheduled rather than an
        // arbitrary Dictionary iteration order.
        let sortedEntries = scheduleMap.sorted { $0.key < $1.key }

        // Every request is built before anything is sent, while the SwiftData
        // objects behind them are still in hand.
        var requests: [UNNotificationRequest] = []
        for (triggerDate, medsAtTime) in sortedEntries {
            guard requests.count < Self.maxScheduled else { break }

            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

            requests.append(
                Self.makeReminderRequest(
                    identifier: UUID().uuidString,
                    medicationIds: medsAtTime.map { $0.medication.id.uuidString },
                    medicationNames: medsAtTime.map { $0.medication.name },
                    triggerDate: triggerDate,
                    trigger: trigger
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

        for request in requests {
            do {
                try await center.add(request)
            } catch {
                AppLog.notifications.error("Failed to schedule: \(error.localizedDescription, privacy: .public)")
            }
        }
        AppLog.notifications.debug("Grouped and scheduled notifications: \(requests.count)")
    }

    // MARK: - Snooze

    func scheduleSnooze(for medicationIds: [String], names: [String]) async {
        guard !medicationIds.isEmpty else { return }

        let triggerDate = Date().addingTimeInterval(Self.snoozeInterval)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.snoozeInterval, repeats: false)

        let request = Self.makeReminderRequest(
            identifier: Self.snoozeIdentifier(for: medicationIds),
            medicationIds: medicationIds,
            medicationNames: names,
            triggerDate: triggerDate,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            AppLog.notifications.error("Snooze failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Cancellation

    func cancelNotifications(for medicationId: UUID) async {
        let center = UNUserNotificationCenter.current()
        let targetId = medicationId.uuidString

        // A delivered notification cannot be edited, so only those that referred
        // to this medication EXCLUSIVELY are removed. It used to remove any
        // notification mentioning the id, taking the reminder for the other
        // medications in the same slot with it.
        let delivered = await center.deliveredNotifications()
        let deliveredToRemove = delivered
            .filter { Self.medicationIds(in: $0.request.content) == [targetId] }
            .map(\.request.identifier)

        if !deliveredToRemove.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredToRemove)
            AppLog.notifications.debug("Removed from lock screen: \(deliveredToRemove.count)")
        }

        // Pending ones, snoozes included — they are recognised by userInfo, not
        // by identifier format. A group reminder is rebuilt without this
        // medication rather than dropped whole.
        let pending = await center.pendingNotificationRequests()
        var identifiersToRemove: [String] = []
        var replacements: [UNNotificationRequest] = []

        for request in pending {
            let ids = Self.medicationIds(in: request.content)
            guard ids.contains(targetId) else { continue }

            identifiersToRemove.append(request.identifier)

            let names = Self.medicationNames(in: request.content)
            // Names came later: requests scheduled by an older version do not carry
            // them, so there is nothing to rebuild the text from — just remove.
            guard names.count == ids.count else { continue }

            let kept = zip(ids, names).filter { $0.0 != targetId }
            guard !kept.isEmpty,
                  let trigger = request.trigger,
                  let time = request.content.userInfo["time"] as? TimeInterval
            else { continue }

            replacements.append(
                Self.makeReminderRequest(
                    identifier: request.identifier,
                    medicationIds: kept.map(\.0),
                    medicationNames: kept.map(\.1),
                    triggerDate: Date(timeIntervalSince1970: time),
                    // The trigger is reused as is. For a calendar trigger that is
                    // exact; an interval (snooze) trigger restarts its countdown,
                    // which is acceptable for 15 minutes.
                    trigger: trigger
                )
            )
        }

        guard !identifiersToRemove.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        AppLog.notifications.debug("Cancelled pending notifications: \(identifiersToRemove.count)")

        for request in replacements {
            do {
                try await center.add(request)
            } catch {
                AppLog.notifications.error("Regroup failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
