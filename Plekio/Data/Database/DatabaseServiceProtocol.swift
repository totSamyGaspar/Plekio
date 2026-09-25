//
//  DatabaseServiceProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

// Writes throw `DatabaseError` so a failed save is never shown as success.
// Reads return empty on failure; the failure is logged and reported once.

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
    func fetchPills(onDays days: [Date]) -> [Date: [PillDose]]

    /// Flips one dose, for a single card's checkbox. The bulk operations are not toggles.
    func togglePill(medicationId: UUID, scheduledTime: Date) throws

    /// Logs every open dose of one slot as taken. Idempotent: taken doses stay taken.
    func markDosesTaken(medicationIds: [UUID], scheduledTime: Date) throws

    /// Reverses `markDosesTaken` for one slot; untaken doses are left alone.
    func unmarkDosesTaken(medicationIds: [UUID], scheduledTime: Date) throws

    /// Records a deliberate skip for one slot; taken doses are left as they are.
    func skipDoses(medicationIds: [UUID], scheduledTime: Date) throws

    /// Reverses `skipDoses` for one slot; only ever un-skips.
    func unskipDoses(medicationIds: [UUID], scheduledTime: Date) throws
}

// MARK: - DoseStoring Defaults

extension DoseStoring {

    /// Day by day; DatabaseService overrides it to read courses once.
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

// MARK: - Blood Pressure

@MainActor
protocol BloodPressureStoring {
    func saveBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) throws
    func fetchAllBloodPressureReadings() -> [BloodPressureReading]
    func deleteBloodPressureReading(_ reading: BloodPressureReading) throws
    func deleteAllBloodPressureReadings() throws
}

// MARK: - DatabaseServiceProtocol

/// The whole storage surface, for the composition root and test double only.
@MainActor
protocol DatabaseServiceProtocol: CourseStoring, DoseStoring, DiaryStoring, BloodPressureStoring, DatabaseChangeSource {}
