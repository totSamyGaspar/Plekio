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
    func scheduleSnooze(for medicationIds: [String], combinedNames: String)
    /// Cancels ALL pending (not yet shown) local notifications.
    /// Single entry point instead of calling UNUserNotificationCenter directly from ViewModel/View.
    func removeAllPending()
}
