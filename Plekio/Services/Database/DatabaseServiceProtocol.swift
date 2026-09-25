//
//  DatabaseServiceProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

//  One protocol per part of the domain, so a consumer asks for what it uses: the
//  dashboard cannot reach the diary, and the notification service — which needs
//  only the list of courses — does not take the whole database.
//
//  All mutating methods throw `DatabaseError` when the write fails, so a failed
//  save can never be reported to the UI as a success. Reads deliberately stay
//  non-throwing: on failure they return an empty result — degradation rather than
//  data loss — but the failure is logged and shown to the user once, so a broken
//  store is not mistaken for an empty one (DatabaseService.fetch).

// MARK: - Courses

@MainActor
protocol CourseStoring {
    func saveCourse(name: String, startDate: Date, endDate: Date, drafts: [MedicationDraft]) throws
    func duplicateCourse(_ course: TreatmentCourse, startDate: Date, endDate: Date) throws

    func fetchAllCourses() -> [TreatmentCourse]
    func fetchCourse(id: UUID) -> TreatmentCourse?

    func deleteCourse(_ course: TreatmentCourse) throws
    func deleteMedication(_ medication: MedicationItem) throws

    func updateCourseDetails(course: TreatmentCourse, name: String, startDate: Date, endDate: Date) throws
    func updateMedication(_ medication: MedicationItem, with draft: MedicationDraft) throws
    func addMedication(draft: MedicationDraft, to course: TreatmentCourse) throws
    func refillStock(for medication: MedicationItem, amount: Int) throws
}

// MARK: - Doses

@MainActor
protocol DoseStoring {
    func fetchPills(for date: Date, preFetchedCourses: [TreatmentCourse]?) -> [PillDose]

    /// The schedule for several days at once, keyed by start of day.
    ///
    /// For screens that look at a range — the week strip, the 30-day streak.
    /// They used to fetch every course themselves just to pass the models back
    /// in as `preFetchedCourses`, so the store would not query courses once per
    /// day: an optimisation that put SwiftData models into two view models.
    /// The store does it here instead.
    func fetchPills(onDays days: [Date]) -> [Date: [PillDose]]

    /// Flips one dose. For the checkbox on a single card, where a toggle is what
    /// the control actually means — the bulk operations below are not toggles.
    func togglePill(medicationId: UUID, scheduledTime: Date) throws

    /// Logs every still-open dose of one slot as taken, in one transaction.
    /// Idempotent: a dose already logged is left alone rather than toggled off.
    func markDosesTaken(medicationIds: [UUID], scheduledTime: Date) throws

    /// Reverses `markDosesTaken` for one slot, in one transaction. Doses that are
    /// not logged as taken are left alone.
    func unmarkDosesTaken(medicationIds: [UUID], scheduledTime: Date) throws

    /// Records a deliberate skip for the medications of one slot. Doses already
    /// taken are left as they are.
    func skipDoses(medicationIds: [UUID], scheduledTime: Date) throws

    /// Reverses `skipDoses` for one slot, in one transaction. Doses that are not
    /// skipped are left alone, so an undo can only ever un-skip.
    func unskipDoses(medicationIds: [UUID], scheduledTime: Date) throws
}

extension DoseStoring {

    /// Day by day, for a store with nothing to share between days — the test
    /// double. DatabaseService overrides it to read the courses once.
    func fetchPills(onDays days: [Date]) -> [Date: [PillDose]] {
        let calendar = Calendar.current
        var result: [Date: [PillDose]] = [:]
        for day in days {
            result[calendar.startOfDay(for: day)] = fetchPills(for: day, preFetchedCourses: nil)
        }
        return result
    }
}

// MARK: - Diary

@MainActor
protocol DiaryStoring {
    func saveDiaryEntry(draft: DiaryEntryDraft) throws
    func updateDiaryEntry(_ entry: DiaryEntry, with draft: DiaryEntryDraft) throws
    func fetchAllDiaryEntries() -> [DiaryEntry]
    func deleteDiaryEntry(_ entry: DiaryEntry) throws
}

// MARK: - Blood pressure

@MainActor
protocol BloodPressureStoring {
    func saveBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) throws
    func fetchAllBloodPressureReadings() -> [BloodPressureReading]
    func deleteBloodPressureReading(_ reading: BloodPressureReading) throws
    func deleteAllBloodPressureReadings() throws
}

// MARK: - Everything

/// The whole storage surface.
///
/// For the composition root and the test double, which do have to cover all of
/// it. A view model should take the one or two protocols above that it actually
/// uses instead.
@MainActor
protocol DatabaseServiceProtocol: CourseStoring, DoseStoring, DiaryStoring, BloodPressureStoring, DatabaseChangeSource {}
