//
//  NotificationServiceProtocol.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.06.2026.
//

import Foundation

protocol NotificationServiceProtocol {

    /// Returns whether notifications ended up allowed, so a caller that only
    /// arms a reminder if permission was granted can do that.
    @discardableResult
    func requestPermission() async -> Bool

    func scheduleNotifications(activeCourses: [TreatmentCourse]) async
    func cancelNotifications(for medicationId: UUID) async
    func scheduleSnooze(for medicationIds: [String], names: [String]) async

    /// Arms the daily diary reminder at `minuteOfDay` minutes past midnight,
    /// replacing whatever was armed before. One repeating request, so it costs a
    /// single slot of the 64 iOS allows however long the horizon is.
    func scheduleDiaryReminder(minuteOfDay: Int) async

    func cancelDiaryReminder()

    /// Cancels ALL pending (not yet shown) local notifications, and does not
    /// return until the notification centre has actually done it. Single entry
    /// point, so a ViewModel/View never reaches into UNUserNotificationCenter
    /// itself.
    func removeAllPending() async

    /// Removes an already DELIVERED reminder for one slot from the lock screen.
    /// `removeAllPending` does not reach these — it only cancels notifications that
    /// are scheduled but have not fired yet. Needed after logging an overdue dose,
    /// or the banner for a dose the user just recorded keeps hanging there.
    func clearDelivered(takenMedicationIds: [UUID], scheduledTime: Date) async

    /// Full rebuild of the schedule: drop everything pending, then re-plan from
    /// the unfinished courses. A requirement rather than only an extension so the
    /// real service can serialize overlapping rebuilds — see NotificationService.
    func rescheduleAll(using dbService: DatabaseServiceProtocol) async
}

extension NotificationServiceProtocol {

    /// The "still running" rule for a course, in one place.
    ///
    /// This, and the three lines around it, were copied verbatim into five call
    /// sites (PillFlowApp, DashboardViewModel, NewTreatmentViewModel and twice in
    /// CourseDetailViewModel), so changing the rule meant finding all five.
    @MainActor
    func activeCourses(from dbService: DatabaseServiceProtocol) -> [TreatmentCourse] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return dbService.fetchAllCourses().filter {
            Calendar.current.startOfDay(for: $0.endDate) >= startOfToday
        }
    }

    /// Plain rebuild, for test doubles and any future implementation that has no
    /// queue of its own to protect. NotificationService overrides this to chain
    /// overlapping calls instead of letting them interleave.
    @MainActor
    func rescheduleAll(using dbService: DatabaseServiceProtocol) async {
        await removeAllPending()
        await scheduleNotifications(activeCourses: activeCourses(from: dbService))
    }
}
