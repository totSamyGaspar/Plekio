import Foundation
@testable import PillFlow

@MainActor
final class MockDatabaseService: DatabaseServiceProtocol {

    // MARK: - Stub properties (control what the mock returns)
    var pillsToReturn: [PillDose] = []
    var coursesToReturn: [TreatmentCourse] = []

    // MARK: - Spy properties (record calls for assertions)
    var didCallSaveCourse = false
    var savedCourseName: String?

    var fetchedPillsDate: Date?

    var toggledPillMedicationId: UUID?
    var toggledPillScheduledTime: Date?

    var deletedCourse: TreatmentCourse?
    var deletedMedication: MedicationItem?

    var didCallUpdateCourseDetails = false
    var updatedCourseName: String?

    var addedMedicationDraft: MedicationDraft?
    var addedToCourse: TreatmentCourse?

    var updatedMedication: MedicationItem?
    var updatedMedicationDraft: MedicationDraft?

    var refilledMedication: MedicationItem?
    var refilledAmount: Int?

    // MARK: - Protocol Implementation

    func saveCourse(name: String, startDate: Date, endDate: Date, drafts: [MedicationDraft]) {
        didCallSaveCourse = true
        savedCourseName = name
    }

    func fetchPills(for date: Date, preFetchedCourses: [TreatmentCourse]? = nil) -> [PillDose] {
        fetchedPillsDate = date
        return pillsToReturn
    }

    func togglePill(medicationId: UUID, scheduledTime: Date) {
        toggledPillMedicationId = medicationId
        toggledPillScheduledTime = scheduledTime
    }

    func fetchAllCourses() -> [TreatmentCourse] {
        return coursesToReturn
    }

    func deleteCourse(_ course: TreatmentCourse) {
        deletedCourse = course
    }

    func deleteMedication(_ medication: MedicationItem) {
        deletedMedication = medication
    }

    func updateCourseDetails(course: TreatmentCourse, name: String, startDate: Date, endDate: Date) {
        didCallUpdateCourseDetails = true
        updatedCourseName = name
    }

    func updateMedication(_ medication: MedicationItem, with draft: MedicationDraft) {
        updatedMedication = medication
        updatedMedicationDraft = draft
    }

    func addMedication(draft: MedicationDraft, to course: TreatmentCourse) {
        addedMedicationDraft = draft
        addedToCourse = course
    }

    func refillStock(for medication: MedicationItem, amount: Int) {
        refilledMedication = medication
        refilledAmount = amount
    }
}
