//
//  DatabaseServiceProtocol.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

/// All mutating methods throw `DatabaseError` when the write fails. A silent
/// `try?` inside the service used to tell the UI "saved" while showing data
/// that never reached disk.
///
/// Reads deliberately stay non-throwing: on failure they return an empty
/// result — degradation rather than data loss.
@MainActor
protocol DatabaseServiceProtocol {
    func saveCourse(name: String, startDate: Date, endDate: Date, drafts: [MedicationDraft]) throws
    func duplicateCourse(_ course: TreatmentCourse, startDate: Date, endDate: Date) throws
    func togglePill(medicationId: UUID, scheduledTime: Date) throws

    func fetchPills(for date: Date, preFetchedCourses: [TreatmentCourse]?) -> [PillDose]
    func fetchAllCourses() -> [TreatmentCourse]
    func fetchCourse(id: UUID) -> TreatmentCourse?
    func deleteCourse(_ course: TreatmentCourse) throws
    func deleteMedication(_ medication: MedicationItem) throws

    func updateCourseDetails(course: TreatmentCourse, name: String, startDate: Date, endDate: Date) throws
    func updateMedication(_ medication: MedicationItem, with draft: MedicationDraft) throws
    func addMedication(draft: MedicationDraft, to course: TreatmentCourse) throws
    func refillStock(for medication: MedicationItem, amount: Int) throws

    // MARK: - Blood pressure

    func saveBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) throws
    func fetchAllBloodPressureReadings() -> [BloodPressureReading]
    func deleteBloodPressureReading(_ reading: BloodPressureReading) throws
    func deleteAllBloodPressureReadings() throws

    // MARK: - Diary

    func saveDiaryEntry(draft: DiaryEntryDraft) throws
    func updateDiaryEntry(_ entry: DiaryEntry, with draft: DiaryEntryDraft) throws
    func fetchAllDiaryEntries() -> [DiaryEntry]
    func deleteDiaryEntry(_ entry: DiaryEntry) throws
}
