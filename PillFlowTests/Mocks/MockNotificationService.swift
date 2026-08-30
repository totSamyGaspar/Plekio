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
    var scheduledDiaryReminderMinute: Int?
    var didCancelDiaryReminder = false

    func requestPermission() {
        didCallRequestPermission = true
    }

    func scheduleNotifications(activeCourses: [TreatmentCourse]) {
        scheduledCourses = activeCourses
    }

    func cancelNotifications(for medicationId: UUID) {
        cancelledMedicationIds.append(medicationId)
    }

    func scheduleSnooze(for medicationIds: [String], names: [String]) {
        snoozedMedicationIds = medicationIds
    }

    func removeAllPending() {
        didCallRemoveAllPending = true
    }

    func scheduleDiaryReminder(minuteOfDay: Int) {
        scheduledDiaryReminderMinute = minuteOfDay
    }

    func cancelDiaryReminder() {
        didCancelDiaryReminder = true
    }

    func clearDelivered(takenMedicationIds: [UUID], scheduledTime: Date) {
        clearDeliveredCallCount += 1
        clearedDeliveredIds = takenMedicationIds
        clearedDeliveredSlot = scheduledTime
    }
}
