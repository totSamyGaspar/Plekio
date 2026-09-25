//
//  ReminderRequestFactory.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Foundation
import UserNotifications

/// Builds every `UNNotificationRequest` the app schedules; decides nothing.
enum ReminderRequestFactory {

    // MARK: - Constants

    static let doseCategoryIdentifier = "PILL_REMINDER_CATEGORY"

    /// Snooze delay; must match the "Snooze 15m" action title.
    static let snoozeInterval: TimeInterval = 15 * 60

    // MARK: - Dose Reminders

    static func doseReminder(
        identifier: String,
        medicationIds: [String],
        medicationNames: [String],
        triggerDate: Date,
        trigger: UNNotificationTrigger
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        // Localized now; safe because the schedule is rebuilt on every scene activation.
        content.title = String(localized: "💊 Time to take your meds")
        // Locale-aware list formatting.
        let names = medicationNames.formatted(.list(type: .and))
        content.body = String(localized: "Time to take: \(names)")
        content.sound = .default
        content.categoryIdentifier = doseCategoryIdentifier
        content.userInfo = ReminderPayload.userInfo(
            medicationIds: medicationIds,
            medicationNames: medicationNames,
            triggerDate: triggerDate
        )
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    /// A non-repeating dose reminder for a fixed date.
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

    /// Sorted so scheduling and cancelling agree on the same id for a group.
    static func snoozeIdentifier(for medicationIds: [String]) -> String {
        "SNOOZE_" + medicationIds.sorted().joined(separator: "_")
    }

    static func snooze(
        medicationIds: [String],
        names: [String],
        from now: Date
    ) -> UNNotificationRequest {
        doseReminder(
            identifier: snoozeIdentifier(for: medicationIds),
            medicationIds: medicationIds,
            medicationNames: names,
            triggerDate: now.addingTimeInterval(snoozeInterval),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: snoozeInterval, repeats: false)
        )
    }

    // MARK: - Daily Reminders

    /// Repeating, so each time costs exactly one of iOS's 64 pending slots.
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
        // No medicationIds: that is how responses tell daily reminders apart.
        content.userInfo = [DailyReminder.userInfoKey: reminder.rawValue]

        return UNNotificationRequest(
            identifier: reminder.requestIdentifier(at: index),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }

    // MARK: - Categories

    /// The dose category with Take/Snooze/Skip, plus one action-less category per daily reminder.
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
