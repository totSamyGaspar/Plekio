import Foundation
@testable import PillFlow

@MainActor
final class MockDatabaseService: DatabaseServiceProtocol {

    // MARK: - Stub properties (control what the mock returns)
    var pillsToReturn: [PillDose] = []
    /// Per-day schedule, keyed by start of day. A date with no entry falls back to
    /// `pillsToReturn`, so tests written before this existed still work.
    var pillsByDay: [Date: [PillDose]] = [:]
    var coursesToReturn: [TreatmentCourse] = []
    var diaryEntriesToReturn: [DiaryEntry] = []

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

    var savedDiaryDraft: DiaryEntryDraft?
    var updatedDiaryEntry: DiaryEntry?
    var updatedDiaryDraft: DiaryEntryDraft?
    var deletedDiaryEntry: DiaryEntry?

    var bloodPressureReadingsToReturn: [BloodPressureReading] = []
    var savedBloodPressure: (measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?)?
    var deletedBloodPressureReading: BloodPressureReading?

    // MARK: - Protocol Implementation

    func saveCourse(name: String, startDate: Date, endDate: Date, drafts: [MedicationDraft]) throws {
        didCallSaveCourse = true
        savedCourseName = name
    }

    func fetchPills(for date: Date, preFetchedCourses: [TreatmentCourse]? = nil) -> [PillDose] {
        fetchedPillsDate = date
        if let scheduled = pillsByDay[Calendar.current.startOfDay(for: date)] {
            return scheduled
        }
        return pillsToReturn
    }

    func togglePill(medicationId: UUID, scheduledTime: Date) throws {
        toggledPillMedicationId = medicationId
        toggledPillScheduledTime = scheduledTime

        // Mirror the real service: the next fetchPills must return the slot with its
        // new isTaken. Without this there is no way to test view-model logic that
        // inspects the state AFTER the write, such as "is the whole slot closed".
        for index in pillsToReturn.indices
        where pillsToReturn[index].medicationId == medicationId
            && pillsToReturn[index].time == scheduledTime {
            pillsToReturn[index].isTaken.toggle()
        }
    }

    func fetchAllCourses() -> [TreatmentCourse] {
        return coursesToReturn
    }

    func fetchCourse(id: UUID) -> TreatmentCourse? {
        coursesToReturn.first { $0.id == id }
    }

    func deleteCourse(_ course: TreatmentCourse) throws {
        deletedCourse = course
    }

    func deleteMedication(_ medication: MedicationItem) throws {
        deletedMedication = medication
    }

    func updateCourseDetails(course: TreatmentCourse, name: String, startDate: Date, endDate: Date) throws {
        didCallUpdateCourseDetails = true
        updatedCourseName = name
    }

    func updateMedication(_ medication: MedicationItem, with draft: MedicationDraft) throws {
        updatedMedication = medication
        updatedMedicationDraft = draft
    }

    func addMedication(draft: MedicationDraft, to course: TreatmentCourse) throws {
        addedMedicationDraft = draft
        addedToCourse = course
    }

    func refillStock(for medication: MedicationItem, amount: Int) throws {
        refilledMedication = medication
        refilledAmount = amount
    }

    func saveBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) throws {
        savedBloodPressure = (measuredAt, systolic, diastolic, pulse)
    }

    func fetchAllBloodPressureReadings() -> [BloodPressureReading] {
        bloodPressureReadingsToReturn
    }

    func deleteBloodPressureReading(_ reading: BloodPressureReading) throws {
        deletedBloodPressureReading = reading
    }

    func saveDiaryEntry(draft: DiaryEntryDraft) throws {
        savedDiaryDraft = draft
    }

    func updateDiaryEntry(_ entry: DiaryEntry, with draft: DiaryEntryDraft) throws {
        updatedDiaryEntry = entry
        updatedDiaryDraft = draft
    }

    func fetchAllDiaryEntries() -> [DiaryEntry] {
        return diaryEntriesToReturn
    }

    func deleteDiaryEntry(_ entry: DiaryEntry) throws {
        deletedDiaryEntry = entry
    }
}
