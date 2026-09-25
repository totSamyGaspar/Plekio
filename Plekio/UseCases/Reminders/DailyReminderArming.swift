//
//  DailyReminderArming.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - DailyReminderArmResult

enum DailyReminderArmResult: Equatable {
    case armed
    case disarmed
    /// Nothing queued; the caller must switch the toggle back off and explain.
    case permissionDenied
}

// MARK: - DailyReminderArming

@MainActor
final class DailyReminderArming {

    // MARK: - Properties

    private let notifications: NotificationServiceProtocol

    // MARK: - Init

    init(notifications: NotificationServiceProtocol) {
        self.notifications = notifications
    }

    // MARK: - Public

    func apply(_ reminder: DailyReminder, enabled: Bool, minutesOfDay: [Int]) async -> DailyReminderArmResult {
        guard enabled else {
            notifications.cancelDailyReminder(reminder)
            return .disarmed
        }

        // Permission is requested here, not at launch, when the user enables a reminder.
        guard await notifications.requestPermission() else {
            // Remove anything left from an earlier "on".
            notifications.cancelDailyReminder(reminder)
            return .permissionDenied
        }

        await notifications.scheduleDailyReminder(reminder, minutesOfDay: minutesOfDay)
        return .armed
    }
}
