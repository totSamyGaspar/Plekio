//
//  NotificationServiceProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.06.2026.
//

import Foundation

// MARK: - NotificationServiceProtocol

/// Schedules and cancels local reminders. `@MainActor` because the implementation reads SwiftData models.
@MainActor
protocol NotificationServiceProtocol {

    /// Whether notifications ended up allowed.
    @discardableResult
    func requestPermission() async -> Bool

    func scheduleNotifications(activeCourses: [TreatmentCourse]) async
    func cancelNotifications(for medicationId: UUID) async
    /// Reminds again about the doses of `slot` after the snooze interval.
    func scheduleSnooze(for medicationIds: [String], names: [String], slot: Date) async

    /// Arms one repeating request per time (minutes past midnight), replacing all previous times.
    func scheduleDailyReminder(_ reminder: DailyReminder, minutesOfDay: [Int]) async

    func cancelDailyReminder(_ reminder: DailyReminder)

    /// Cancels all pending notifications; returns only once the centre has done it.
    func removeAllPending() async

    /// Removes already delivered reminders for a settled slot; `removeAllPending` does not reach these.
    func clearDelivered(settledMedicationIds: [UUID], scheduledTime: Date) async

    /// Clears pending and re-plans from active courses. A requirement so the real service can serialize it.
    func rescheduleAll(using dbService: any CourseStoring) async
}

// MARK: - Defaults

extension NotificationServiceProtocol {

    /// Courses still running on `day`.
    func activeCourses(from dbService: any CourseStoring, on day: Date, calendar: Calendar) -> [TreatmentCourse] {
        dbService.fetchAllCourses().filter { $0.isActive(on: day, calendar: calendar) }
    }

    /// Unserialized rebuild for test doubles; NotificationService overrides it.
    func rescheduleAll(using dbService: any CourseStoring) async {
        await removeAllPending()
        let clock = SystemTime()
        await scheduleNotifications(activeCourses: activeCourses(from: dbService, on: clock.now, calendar: clock.calendar))
    }
}
