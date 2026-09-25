import Foundation
@testable import Plekio

@MainActor
final class MockDatabaseService: DatabaseServiceProtocol {

    /// Silent unless a test sends on it: the mock's writes do not announce
    /// themselves, so a view model refreshes only when the test says so.
    let changes = DatabaseChangeFeed()

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

    var duplicatedCourse: TreatmentCourse?
    var duplicatedStartDate: Date?
    var duplicatedEndDate: Date?

    var fetchedPillsDate: Date?

    var markedTakenSlots: [(medicationIds: [UUID], scheduledTime: Date)] = []
    var unmarkedTakenSlots: [(medicationIds: [UUID], scheduledTime: Date)] = []
    var skippedSlots: [(medicationIds: [UUID], scheduledTime: Date)] = []
    var unskippedSlots: [(medicationIds: [UUID], scheduledTime: Date)] = []

    var toggledPillMedicationId: UUID?
    var toggledPillScheduledTime: Date?
    /// Every toggle in order. The single-value spies above keep the last call, which
    /// cannot show that a bulk log left an already-taken dose alone.
    var toggleCalls: [(medicationId: UUID, scheduledTime: Date)] = []

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
    var didCallDeleteAllBloodPressureReadings = false

    // MARK: - Protocol Implementation

    func saveCourse(name: String, startDate: Date, endDate: Date, drafts: [MedicationDraft]) throws {
        didCallSaveCourse = true
        savedCourseName = name
    }

    func duplicateCourse(_ course: TreatmentCourse, startDate: Date, endDate: Date) throws {
        duplicatedCourse = course
        duplicatedStartDate = startDate
        duplicatedEndDate = endDate
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
        toggleCalls.append((medicationId, scheduledTime))

        // Mirror the real service: the next fetchPills must return the slot with its
        // new status. Without this there is no way to test view-model logic that
        // inspects the state AFTER the write, such as "is the whole slot closed".
        for index in pillsToReturn.indices
        where pillsToReturn[index].medicationId == medicationId
            && pillsToReturn[index].time == scheduledTime {
            let status = pillsToReturn[index].status
            pillsToReturn[index].status = status.isTaken ? .pending : .taken(at: Date(), dispensed: pillsToReturn[index].dosage)
        }
    }

    /// Set to make markDosesTaken fail, for tests of how a failed write is surfaced.
    var markTakenError: Error?

    func markDosesTaken(medicationIds: [UUID], scheduledTime: Date) throws {
        if let markTakenError { throw markTakenError }
        markedTakenSlots.append((medicationIds, scheduledTime))

        for index in pillsToReturn.indices
        where medicationIds.contains(pillsToReturn[index].medicationId)
            && pillsToReturn[index].time == scheduledTime {
            let dosage = pillsToReturn[index].dosage
            if let taken = pillsToReturn[index].status.taking(at: Date(), dispensed: dosage) {
                pillsToReturn[index].status = taken
            }
        }
    }

    func unmarkDosesTaken(medicationIds: [UUID], scheduledTime: Date) throws {
        unmarkedTakenSlots.append((medicationIds, scheduledTime))

        for index in pillsToReturn.indices
        where medicationIds.contains(pillsToReturn[index].medicationId)
            && pillsToReturn[index].time == scheduledTime {
            if let reverted = pillsToReturn[index].status.reverting() {
                pillsToReturn[index].status = reverted.status
            }
        }
    }

    func skipDoses(medicationIds: [UUID], scheduledTime: Date) throws {
        skippedSlots.append((medicationIds, scheduledTime))

        // Mirror the real service, so a view model that re-reads after the write
        // sees the skip — same reason togglePill flips the status here. The moves
        // are DoseStatus's own, so the mock cannot drift from the real rules.
        for index in pillsToReturn.indices
        where medicationIds.contains(pillsToReturn[index].medicationId)
            && pillsToReturn[index].time == scheduledTime {
            if let skipped = pillsToReturn[index].status.skipping(at: Date()) {
                pillsToReturn[index].status = skipped
            }
        }
    }

    func unskipDoses(medicationIds: [UUID], scheduledTime: Date) throws {
        unskippedSlots.append((medicationIds, scheduledTime))

        for index in pillsToReturn.indices
        where medicationIds.contains(pillsToReturn[index].medicationId)
            && pillsToReturn[index].time == scheduledTime {
            if let pending = pillsToReturn[index].status.unskipping() {
                pillsToReturn[index].status = pending
            }
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

    func deleteAllBloodPressureReadings() throws {
        didCallDeleteAllBloodPressureReadings = true
        bloodPressureReadingsToReturn = []
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
