//
//  DailyReminderArming.swift
//  Plekio
//
//  Switching a daily reminder on or off, and what came of it.
//
//  This lived in the Settings row, where it could not be tested — and it had a
//  hole: when the user declined notifications, it returned quietly. The switch
//  stayed on and was saved as on, so the screen said "reminder on" for a
//  reminder that could never fire, and nothing ever said otherwise. The outcome
//  is now a value the row has to handle.
//

import Foundation

enum DailyReminderArmResult: Equatable {
    /// On, with its requests in the queue.
    case armed
    /// Off, with its requests removed.
    case disarmed
    /// Asked to switch on, but notifications are not allowed. Nothing is
    /// queued; the caller has to switch it back off and say why.
    case permissionDenied
}

@MainActor
final class DailyReminderArming {

    private let notifications: NotificationServiceProtocol

    init(notifications: NotificationServiceProtocol) {
        self.notifications = notifications
    }

    func apply(_ reminder: DailyReminder, enabled: Bool, minutesOfDay: [Int]) async -> DailyReminderArmResult {
        guard enabled else {
            notifications.cancelDailyReminder(reminder)
            return .disarmed
        }

        // Asked here rather than at launch: switching a reminder on is the moment
        // the permission is actually for something.
        guard await notifications.requestPermission() else {
            // Nothing half-armed left behind from an earlier "on".
            notifications.cancelDailyReminder(reminder)
            return .permissionDenied
        }

        await notifications.scheduleDailyReminder(reminder, minutesOfDay: minutesOfDay)
        return .armed
    }
}
