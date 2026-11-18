//
//  UITestingNotificationService.swift
//  Plekio
//
//  Created by Edward Gasparian on 18.11.2026.
//

#if DEBUG
import Foundation

// MARK: - UITestingNotificationService

/// Schedules nothing and never asks for permission. A system permission alert
/// would block every UI test, and test reminders must not ring on the device.
/// Reports `.on`, so Today doesn't show the "notifications are off" card.
final class UITestingNotificationService: NotificationServiceProtocol {

    @discardableResult
    func requestPermission() async -> Bool { true }

    func delivery() async -> ReminderDelivery { .on }

    func scheduleNotifications(activeCourses: [TreatmentCourse]) async {}
    func cancelNotifications(for medicationId: UUID) async {}
    func scheduleSnooze(for medicationIds: [String], names: [String], slot: Date) async {}
    func scheduleDailyReminder(_ reminder: DailyReminder, minutesOfDay: [Int]) async {}
    func cancelDailyReminder(_ reminder: DailyReminder) {}
    func removeAllPending() async {}
    func clearDelivered(settledMedicationIds: [UUID], scheduledTime: Date) async {}
}
#endif
