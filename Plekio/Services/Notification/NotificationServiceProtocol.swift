//
//  NotificationServiceProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.06.2026.
//

import Foundation

/// `@MainActor`, like DatabaseServiceProtocol and the view-model protocols.
/// Every caller is a view or a view model, and the implementation reads
/// SwiftData models — but until this said so, the requirements were nonisolated
/// while their witnesses were not, and passing `[TreatmentCourse]` to an async
/// one counted as sending a non-Sendable value across an actor boundary.
@MainActor
protocol NotificationServiceProtocol {

    /// Returns whether notifications ended up allowed, so a caller that only
    /// arms a reminder if permission was granted can do that.
    @discardableResult
    func requestPermission() async -> Bool

    func scheduleNotifications(activeCourses: [TreatmentCourse]) async
    func cancelNotifications(for medicationId: UUID) async
    func scheduleSnooze(for medicationIds: [String], names: [String]) async

    /// Arms a daily reminder at each of `minutesOfDay` (minutes past midnight),
    /// replacing whatever was armed before — including times the reminder no
    /// longer uses. One repeating request per time, so each costs a single slot
    /// of the 64 iOS allows however long the dose horizon is.
    func scheduleDailyReminder(_ reminder: DailyReminder, minutesOfDay: [Int]) async

    func cancelDailyReminder(_ reminder: DailyReminder)

    /// Cancels ALL pending (not yet shown) local notifications, and does not
    /// return until the notification centre has actually done it. Single entry
    /// point, so a ViewModel/View never reaches into UNUserNotificationCenter
    /// itself.
    func removeAllPending() async

    /// Removes an already DELIVERED reminder for one slot from the lock screen.
    /// `removeAllPending` does not reach these — it only cancels notifications that
    /// are scheduled but have not fired yet. Needed after logging an overdue dose,
    /// or skipping one, or the banner for a dose the user just answered for keeps
    /// hanging there.
    func clearDelivered(settledMedicationIds: [UUID], scheduledTime: Date) async

    /// Full rebuild of the schedule: drop everything pending, then re-plan from
    /// the unfinished courses. A requirement rather than only an extension so the
    /// real service can serialize overlapping rebuilds — see NotificationService.
    func rescheduleAll(using dbService: any CourseStoring) async
}

extension NotificationServiceProtocol {

    /// The "still running" rule for a course, in one place.
    ///
    /// This, and the three lines around it, were copied verbatim into five call
    /// sites (PlekioApp, DashboardViewModel, NewTreatmentViewModel and twice in
    /// CourseDetailViewModel), so changing the rule meant finding all five.
    func activeCourses(from dbService: any CourseStoring, on day: Date, calendar: Calendar) -> [TreatmentCourse] {
        dbService.fetchAllCourses().filter { $0.isActive(on: day, calendar: calendar) }
    }

    /// Plain rebuild, for test doubles and any future implementation that has no
    /// queue of its own to protect. NotificationService overrides this to chain
    /// overlapping calls instead of letting them interleave.
    func rescheduleAll(using dbService: any CourseStoring) async {
        await removeAllPending()
        // A double has no TimeSource of its own; the real clock is what the
        // tests of this path have always used.
        let clock = SystemTime()
        await scheduleNotifications(activeCourses: activeCourses(from: dbService, on: clock.now, calendar: clock.calendar))
    }
}
