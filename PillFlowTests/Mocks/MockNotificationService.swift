import Foundation
@testable import PillFlow

final class MockNotificationService: NotificationServiceProtocol {

    var didCallRequestPermission = false
    var scheduledCourses: [TreatmentCourse]?
    var cancelledMedicationIds: [UUID] = []
    var snoozedMedicationIds: [String]?
    var didCallRemoveAllPending = false

    func requestPermission() {
        didCallRequestPermission = true
    }

    func scheduleNotifications(activeCourses: [TreatmentCourse]) {
        scheduledCourses = activeCourses
    }

    func cancelNotifications(for medicationId: UUID) {
        cancelledMedicationIds.append(medicationId)
    }

    func scheduleSnooze(for medicationIds: [String], combinedNames: String) {
        snoozedMedicationIds = medicationIds
    }

    func removeAllPending() {
        didCallRemoveAllPending = true
    }
}
