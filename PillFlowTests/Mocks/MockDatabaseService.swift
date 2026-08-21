import Foundation
@testable import PillFlow

@MainActor
final class MockDatabaseService: DatabaseServiceProtocol {
    
    // MARK: - Свойства для управления ответами мока (Stubs)
    var pillsToReturn: [PillDose] = []
    var coursesToReturn: [TreatmentCourse] = []
    
    // MARK: - Свойства для проверки вызовов (Spies)
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
    
    // MARK: - Реализация протокола
    
    func saveCourse(name: String, startDate: Date, endDate: Date, drafts: [MedicationDraft]) {
        didCallSaveCourse = true
        savedCourseName = name
    }
    
    func fetchPills(for date: Date) -> [PillDose] {
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
    
    func addMedication(draft: MedicationDraft, to course: TreatmentCourse) {
        addedMedicationDraft = draft
        addedToCourse = course
    }
}
