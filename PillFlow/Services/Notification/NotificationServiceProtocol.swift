//
//  NotificationServiceProtocol.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.06.2026.
//

import Foundation

protocol NotificationServiceProtocol {
    func requestPermission()
    func scheduleNotifications(activeCourses: [TreatmentCourse])
    func cancelNotifications(for medicationId: UUID)
    func scheduleSnooze(for medicationIds: [String], names: [String])
    /// Cancels ALL pending (not yet shown) local notifications. Single entry point,
    /// so a ViewModel/View never reaches into UNUserNotificationCenter itself.
    func removeAllPending()

    /// Removes an already DELIVERED reminder for one slot from the lock screen.
    /// `removeAllPending` does not reach these — it only cancels notifications that
    /// are scheduled but have not fired yet. Needed after logging an overdue dose,
    /// or the banner for a dose the user just recorded keeps hanging there.
    func clearDelivered(takenMedicationIds: [UUID], scheduledTime: Date)
}

extension NotificationServiceProtocol {

    /// Full rebuild of the schedule: drop everything pending, then re-plan from the
    /// unfinished courses.
    ///
    /// These three lines, and the "active course" criterion with them, were copied
    /// verbatim into five places (PillFlowApp, DashboardViewModel,
    /// NewTreatmentViewModel and twice in CourseDetailViewModel), so changing the
    /// rule meant finding all five.
    @MainActor
    func rescheduleAll(using dbService: DatabaseServiceProtocol) {
        removeAllPending()

        let startOfToday = Calendar.current.startOfDay(for: Date())
        let activeCourses = dbService.fetchAllCourses().filter {
            Calendar.current.startOfDay(for: $0.endDate) >= startOfToday
        }

        scheduleNotifications(activeCourses: activeCourses)
    }
}
