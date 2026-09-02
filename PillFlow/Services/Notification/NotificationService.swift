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

final class NotificationService: NotificationServiceProtocol {

    /// Single source of truth for the snooze delay, so the category action's
    /// title and the actual scheduled trigger can't drift out of sync.
    private static let snoozeInterval: TimeInterval = 15 * 60

    private static let categoryIdentifier = "PILL_REMINDER_CATEGORY"

    /// The diary reminder gets its own category: the dose actions (Take, Snooze,
    /// Skip) make no sense on it, and a shared category would put them there.
    private static let diaryCategoryIdentifier = "DIARY_REMINDER_CATEGORY"

    /// A fixed identifier, not a UUID: arming the reminder replaces the previous
    /// one instead of stacking a second copy at the old time.
    private static let diaryRequestIdentifier = "DIARY_REMINDER"

    /// iOS will not schedule more than 64 local notifications per app; leave
    /// some headroom.
    private static let maxScheduled = 60

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

        let diaryCategory = UNNotificationCategory(
            identifier: Self.diaryCategoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        center.setNotificationCategories([category, diaryCategory])
    }

    // MARK: - Permission

    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                AppLog.notifications.error("Permission request failed: \(error.localizedDescription, privacy: .public)")
            } else if !granted {
                AppLog.notifications.info("Notifications declined by user")
            }
        }
    }

    /// Single entry point for clearing all scheduled notifications, so callers
    /// don't reach into UNUserNotificationCenter directly.
    func removeAllPending() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        // The diary reminder is not part of the course schedule but shares the
        // queue, so a course edit would silently take it down with everything
        // else. Re-armed here rather than at the five call sites of
        // rescheduleAll, where forgetting it once is enough to lose it.
        //
        // Re-armed *after* the removal has actually been carried out — see
        // afterPendingRemovalCompletes.
        afterPendingRemovalCompletes { [weak self] in
            self?.restoreDiaryReminderIfEnabled()
        }
    }

    /// Runs `work` once the notification centre has processed everything queued
    /// before this call.
    ///
    /// `removeAllPendingNotificationRequests()` is asynchronous: it returns at once
    /// and the removal happens later, on the centre's own queue. Adding requests
    /// straight afterwards — exactly what `rescheduleAll` does after every edit —
    /// meant the removal could land on top of the freshly added ones and wipe them,
    /// so a medication whose time was changed simply never fired again until the
    /// next cold launch (which raced the same way). The centre processes calls in
    /// order, so a read issued after the removal only calls back once the removal
    /// is done.
    private func afterPendingRemovalCompletes(_ work: @escaping () -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { _ in
            DispatchQueue.main.async(execute: work)
        }
    }

    // MARK: - Diary reminder

    func scheduleDiaryReminder(minuteOfDay: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.diaryRequestIdentifier])

        let (hour, minute) = DiaryReminderSettings.hourAndMinute(from: minuteOfDay)
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = String(localized: "📔 Time for your check-in")
        content.body = String(localized: "Log how you feel today: mood, energy and symptoms")
        content.sound = .default
        content.categoryIdentifier = Self.diaryCategoryIdentifier
        // What tells AppDelegate this is a diary tap: the dose branch keys off
        // medicationIds, which this one deliberately does not carry.
        content.userInfo = ["kind": "diary"]

        // repeats: true — the reminder is not tied to a course and needs no
        // per-day skipping, so one request covers every day for ever.
        let request = UNNotificationRequest(
            identifier: Self.diaryRequestIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        center.add(request) { error in
            if let error {
                AppLog.notifications.error("Diary reminder failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func cancelDiaryReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.diaryRequestIdentifier])
    }

    private func restoreDiaryReminderIfEnabled() {
        guard DiaryReminderSettings.isEnabled else { return }
        scheduleDiaryReminder(minuteOfDay: DiaryReminderSettings.minuteOfDay)
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
    func clearDelivered(takenMedicationIds: [UUID], scheduledTime: Date) {
        guard !takenMedicationIds.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        let takenIds = Set(takenMedicationIds.map { $0.uuidString })
        let slot = scheduledTime.timeIntervalSince1970

        center.getDeliveredNotifications { notifications in
            let toRemove = notifications.compactMap { notif -> String? in
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
    }

    // MARK: - Schedule Building

    /// Pure, side-effect-free computation of what needs to be scheduled, kept
    /// separate from scheduleNotifications so it can be unit tested without a
    /// real notification center. Handles two rules: grouping multiple
    /// medications that share a trigger time into a single push, and skipping
    /// slots that are already logged as taken. `now`/`calendar` default to
    /// live values so production behavior is unaffected; tests inject fixed ones.
    static func buildScheduleMap(
        activeCourses: [TreatmentCourse],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Date: [(courseName: String, medication: MedicationItem)]] {
        let today = calendar.startOfDay(for: now)
        let maxDate = calendar.date(byAdding: .day, value: 2, to: today) ?? today

        var scheduleMap: [Date: [(courseName: String, medication: MedicationItem)]] = [:]

        for course in activeCourses {
            let startDay = calendar.startOfDay(for: course.startDate)
            let endDay = calendar.startOfDay(for: course.endDate)

            for med in course.medications {
                // The loop step is frequencyDays. At zero the date never advances and
                // the while loop hangs the main thread. Zero is unreachable from the UI
                // (the picker offers 1/2/3/7/14/30), but data can arrive from a
                // migration or an import.
                guard med.frequencyDays > 0 else { continue }

                var currentDate = startDay
                while currentDate <= endDay {
                    if currentDate >= today && currentDate <= maxDate {
                        for time in med.timesOfDay {
                            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                            if let triggerDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: currentDate), triggerDate > now {

                                // Skip slots already marked as taken, so a dose logged in
                                // advance doesn't still trigger a reminder.
                                let alreadyTaken = med.logs.contains { log in
                                    log.isTaken &&
                                    calendar.isDate(log.scheduledTime, inSameDayAs: triggerDate) &&
                                    calendar.component(.hour, from: log.scheduledTime) == calendar.component(.hour, from: triggerDate) &&
                                    calendar.component(.minute, from: log.scheduledTime) == calendar.component(.minute, from: triggerDate)
                                }

                                if !alreadyTaken {
                                    scheduleMap[triggerDate, default: []].append((courseName: course.name, medication: med))
                                }
                            }
                        }
                    }
                    if currentDate > maxDate { break }
                    currentDate = calendar.date(byAdding: .day, value: med.frequencyDays, to: currentDate) ?? endDay.addingTimeInterval(1)
                }
            }
        }

        return scheduleMap
    }

    // MARK: - Scheduling

    func scheduleNotifications(activeCourses: [TreatmentCourse]) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current

        let scheduleMap = Self.buildScheduleMap(activeCourses: activeCourses, now: Date(), calendar: calendar)

        // Sort by trigger date so that, if the count exceeds iOS's notification
        // limit, it's the soonest reminders that get scheduled rather than an
        // arbitrary Dictionary iteration order.
        let sortedEntries = scheduleMap.sorted { $0.key < $1.key }

        // Every request is built up front, while the SwiftData objects are still
        // safe to touch on this actor. What goes to the centre afterwards is plain
        // UNNotificationRequest values.
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

        // Queued behind any pending removal: rescheduleAll clears everything first,
        // and that clear is asynchronous.
        let scheduledCount = requests.count
        afterPendingRemovalCompletes {
            for request in requests {
                center.add(request) { error in
                    if let error {
                        AppLog.notifications.error("Failed to schedule: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
            AppLog.notifications.debug("Grouped and scheduled notifications: \(scheduledCount)")
        }
    }

    // MARK: - Snooze

    func scheduleSnooze(for medicationIds: [String], names: [String]) {
        guard !medicationIds.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        let triggerDate = Date().addingTimeInterval(Self.snoozeInterval)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.snoozeInterval, repeats: false)

        let request = Self.makeReminderRequest(
            identifier: Self.snoozeIdentifier(for: medicationIds),
            medicationIds: medicationIds,
            medicationNames: names,
            triggerDate: triggerDate,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                AppLog.notifications.error("Snooze failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Cancellation

    func cancelNotifications(for medicationId: UUID) {
        let center = UNUserNotificationCenter.current()
        let targetId = medicationId.uuidString

        // A delivered notification cannot be edited, so only those that referred
        // to this medication EXCLUSIVELY are removed. It used to remove any
        // notification mentioning the id, taking the reminder for the other
        // medications in the same slot with it.
        center.getDeliveredNotifications { notifications in
            let toRemove = notifications
                .filter { Self.medicationIds(in: $0.request.content) == [targetId] }
                .map(\.request.identifier)

            guard !toRemove.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: toRemove)
            AppLog.notifications.debug("Removed from lock screen: \(toRemove.count)")
        }

        // Pending ones, snoozes included — they are recognised by userInfo, not
        // by identifier format. A group reminder is rebuilt without this
        // medication rather than dropped whole.
        center.getPendingNotificationRequests { requests in
            var identifiersToRemove: [String] = []
            var replacements: [UNNotificationRequest] = []

            for request in requests {
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
                center.add(request) { error in
                    if let error {
                        AppLog.notifications.error("Regroup failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
        }
    }
}
