import Foundation
@testable import PillFlow

final class MockNotificationService: NotificationServiceProtocol {

    var didCallRequestPermission = false
    var scheduledCourses: [TreatmentCourse]?
    var cancelledMedicationIds: [UUID] = []
    var snoozedMedicationIds: [String]?
    var didCallRemoveAllPending = false
    var clearedDeliveredIds: [UUID]?
    var clearedDeliveredSlot: Date?
    var clearDeliveredCallCount = 0
    var scheduledReminders: [DailyReminder: [Int]] = [:]
    var cancelledReminders: [DailyReminder] = []
    /// What requestPermission() answers. Tests that care flip it.
    var permissionGranted = true
    /// Counts rebuilds. `scheduledCourses` is overwritten by each one, so a test
    /// that needs to know a *second* rebuild has happened counts instead.
    var scheduleCallCount = 0

    @discardableResult
    func requestPermission() async -> Bool {
        didCallRequestPermission = true
        return permissionGranted
    }

    func scheduleNotifications(activeCourses: [TreatmentCourse]) async {
        scheduledCourses = activeCourses
        scheduleCallCount += 1
    }

    func cancelNotifications(for medicationId: UUID) async {
        cancelledMedicationIds.append(medicationId)
    }

    func scheduleSnooze(for medicationIds: [String], names: [String]) async {
        snoozedMedicationIds = medicationIds
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

/// Yields the main actor until `condition` holds.
///
/// The view models hand notification work to a `Task` now — the schedule rebuild
/// is asynchronous and nothing on screen waits for it — so an assertion made
/// straight after the call would race it. Yielding beats sleeping for a guessed
/// interval: it costs nothing when the work is already done and does not turn
/// into a flaky test on a loaded machine.
@MainActor
func waitUntil(_ condition: @MainActor () -> Bool, iterations: Int = 500) async -> Bool {
    for _ in 0..<iterations {
        if condition() { return true }
        await Task.yield()
    }
    return condition()
}
