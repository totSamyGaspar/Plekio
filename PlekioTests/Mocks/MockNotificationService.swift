//
//  MockNotificationService.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 22.08.2026.
//

import Foundation
@testable import Plekio

final class MockNotificationService: NotificationServiceProtocol {

    // MARK: - Spies and stubs

    var didCallRequestPermission = false
    var requestPermissionCallCount = 0
    var scheduledCourses: [TreatmentCourse]?
    var cancelledMedicationIds: [UUID] = []
    var snoozedMedicationIds: [String]?
    var snoozedSlot: Date?
    var didCallRemoveAllPending = false
    var clearedDeliveredIds: [UUID]?
    var clearedDeliveredSlot: Date?
    var clearDeliveredCallCount = 0
    var scheduledReminders: [DailyReminder: [Int]] = [:]
    var cancelledReminders: [DailyReminder] = []
    /// What requestPermission() returns.
    var permissionGranted = true
    /// Number of rebuilds; `scheduledCourses` only keeps the last one.
    var scheduleCallCount = 0

    // MARK: - NotificationServiceProtocol

    @discardableResult
    func requestPermission() async -> Bool {
        didCallRequestPermission = true
        requestPermissionCallCount += 1
        return permissionGranted
    }

    func scheduleNotifications(activeCourses: [TreatmentCourse]) async {
        scheduledCourses = activeCourses
        scheduleCallCount += 1
    }

    func cancelNotifications(for medicationId: UUID) async {
        cancelledMedicationIds.append(medicationId)
    }

    func scheduleSnooze(for medicationIds: [String], names: [String], slot: Date) async {
        snoozedMedicationIds = medicationIds
        snoozedSlot = slot
    }

    func removeAllPending() async {
        didCallRemoveAllPending = true
    }

    func scheduleDailyReminder(_ reminder: DailyReminder, minutesOfDay: [Int]) async {
        scheduledReminders[reminder] = minutesOfDay
    }

    func cancelDailyReminder(_ reminder: DailyReminder) {
        cancelledReminders.append(reminder)
    }

    func clearDelivered(settledMedicationIds: [UUID], scheduledTime: Date) async {
        clearDeliveredCallCount += 1
        clearedDeliveredIds = settledMedicationIds
        clearedDeliveredSlot = scheduledTime
    }
}

// MARK: - Waiting

/// Yields the main actor until `condition` holds; returns false if it never does.
/// Notification work runs in a `Task`, so asserting right after the call would race it.
@MainActor
func waitUntil(_ condition: @MainActor () -> Bool, iterations: Int = 500) async -> Bool {
    for _ in 0..<iterations {
        if condition() { return true }
        await Task.yield()
    }
    return condition()
}
