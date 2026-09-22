//
//  ReminderRequestFactory.swift
//  Plekio
//

import Foundation
import UserNotifications

/// Turns a decision into an actual `UNNotificationRequest`.
///
/// Every reminder the app schedules is built here — the initial dose schedule, a
/// group rebuilt after one medication is cancelled, a snooze, a daily reminder —
/// so the text, the category and the userInfo payload cannot drift between them.
/// Pure: it decides nothing and touches no notification centre.
enum ReminderRequestFactory {

    static let doseCategoryIdentifier = "PILL_REMINDER_CATEGORY"

    /// Single source of truth for the snooze delay, so the action's title and the
    /// trigger it actually schedules cannot say different things.
    static let snoozeInterval: TimeInterval = 15 * 60

    // MARK: - Dose reminders

    static func doseReminder(
        identifier: String,
        medicationIds: [String],
        medicationNames: [String],
        triggerDate: Date,
        trigger: UNNotificationTrigger
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = NotificationText.localized("💊 Time to take your meds")
        // Foundation builds the list: the separator and the conjunction before the
        // last item differ from language to language. This one part is settled
        // here rather than at delivery — the API takes arguments, not formatters
        // — so a language changed after scheduling leaves the conjunction behind.
        // A word, against a title and a body that follow.
        let names = medicationNames.formatted(.list(type: .and))
        content.body = NotificationText.localized("Time to take: %@", [names])
        content.sound = .default
        content.categoryIdentifier = doseCategoryIdentifier
        content.userInfo = ReminderPayload.userInfo(
            medicationIds: medicationIds,
            medicationNames: medicationNames,
            triggerDate: triggerDate
        )
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    /// A dose reminder for a fixed date. `repeats: false` — a dose belongs to one
    /// day, and the whole schedule is rebuilt whenever anything changes.
    static func doseReminder(
        medicationIds: [String],
        medicationNames: [String],
        triggerDate: Date,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: triggerDate
        )
        return doseReminder(
            identifier: UUID().uuidString,
            medicationIds: medicationIds,
            medicationNames: medicationNames,
            triggerDate: triggerDate,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    // MARK: - Snooze

    /// One single way to build a snooze identifier — scheduling and cancelling
    /// must agree on it, or a group snooze can never be cancelled. Hence the sort:
    /// the same set of medications always gives the same string.
    static func snoozeIdentifier(for medicationIds: [String]) -> String {
        "SNOOZE_" + medicationIds.sorted().joined(separator: "_")
    }

    static func snooze(
        medicationIds: [String],
        names: [String],
        from now: Date = Date()
    ) -> UNNotificationRequest {
        doseReminder(
            identifier: snoozeIdentifier(for: medicationIds),
            medicationIds: medicationIds,
            medicationNames: names,
            triggerDate: now.addingTimeInterval(snoozeInterval),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: snoozeInterval, repeats: false)
        )
    }

    // MARK: - Daily reminders

    /// `repeats: true` — a daily reminder is not tied to a course and needs no
    /// per-day skipping, so one request covers every day for ever. It is also why
    /// each time costs exactly one slot of the 64 iOS allows, however far ahead the
    /// dose schedule reaches.
    static func dailyReminder(
        _ reminder: DailyReminder,
        minuteOfDay: Int,
        index: Int
    ) -> UNNotificationRequest {
        let (hour, minute) = DailyReminder.hourAndMinute(from: minuteOfDay)
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = reminder.notificationTitle
        content.body = reminder.notificationBody
        content.sound = .default
        content.categoryIdentifier = reminder.categoryIdentifier
        // What tells AppDelegate which screen to open. The dose branch keys off
        // medicationIds, which these deliberately do not carry.
        content.userInfo = [DailyReminder.userInfoKey: reminder.rawValue]

        return UNNotificationRequest(
            identifier: reminder.requestIdentifier(at: index),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }

    // MARK: - Categories

    /// The action buttons a delivered dose reminder carries, plus one bare
    /// category per daily reminder.
    ///
    /// The dose actions make no sense on a diary prompt, and one shared category
    /// would put Take/Snooze/Skip on every reminder the app ever adds.
    ///
    /// These titles stay on `String(localized:)`, unlike the notification text.
    /// Categories are registered again on every launch, and iOS relaunches an
    /// app when the language changes, so they can never be left behind.
    static func categories() -> Set<UNNotificationCategory> {
        let doseCategory = UNNotificationCategory(
            identifier: doseCategoryIdentifier,
            actions: [
                UNNotificationAction(
                    identifier: NotificationAction.take,
                    title: String(localized: "Take Now"),
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: NotificationAction.snooze,
                    title: String(localized: "Snooze 15m"),
                    options: []
                ),
                UNNotificationAction(
                    identifier: NotificationAction.skip,
                    title: String(localized: "Skip"),
                    options: .destructive
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        let reminderCategories = DailyReminder.allCases.map { reminder in
            UNNotificationCategory(
                identifier: reminder.categoryIdentifier,
                actions: [],
                intentIdentifiers: [],
                options: .customDismissAction
            )
        }

        return Set([doseCategory] + reminderCategories)
    }
}
