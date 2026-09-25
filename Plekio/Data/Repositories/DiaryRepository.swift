//
//  DiaryRepository.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - DiaryRepository

@MainActor
protocol DiaryRepository {

    /// Newest first.
    func allEntries() -> [DiaryEntrySnapshot]
    func saveEntry(_ draft: DiaryEntryDraft) throws
    func updateEntry(id: UUID, with draft: DiaryEntryDraft) throws
    func deleteEntry(id: UUID) throws

    func allBloodPressureReadings() -> [BloodPressureSnapshot]
    func saveBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) throws
    func deleteBloodPressureReading(id: UUID) throws
    func deleteAllBloodPressureReadings() throws
}

// MARK: - DiaryRepositoryError

/// A write named an entry or reading that is no longer in the store.
enum DiaryRepositoryError: LocalizedError {
    case notFound

    var errorDescription: String? {
        String(localized: "This item no longer exists. It may have been deleted.")
    }
}

// MARK: - SwiftDataDiaryRepository

@MainActor
final class SwiftDataDiaryRepository: DiaryRepository {

    // MARK: - Properties

    private let store: any DiaryStoring & BloodPressureStoring

    // MARK: - Init

    init(store: any DiaryStoring & BloodPressureStoring) {
        self.store = store
    }

    // MARK: - Entries

    func allEntries() -> [DiaryEntrySnapshot] {
        store.fetchAllDiaryEntries().map { DiaryEntrySnapshot($0) }
    }

    func saveEntry(_ draft: DiaryEntryDraft) throws {
        try store.saveDiaryEntry(draft: draft)
    }

    func updateEntry(id: UUID, with draft: DiaryEntryDraft) throws {
        try store.updateDiaryEntry(try entryModel(id), with: draft)
    }

    func deleteEntry(id: UUID) throws {
        try store.deleteDiaryEntry(try entryModel(id))
    }

    // MARK: - Blood Pressure

    func allBloodPressureReadings() -> [BloodPressureSnapshot] {
        store.fetchAllBloodPressureReadings().map { BloodPressureSnapshot($0) }
    }

    func saveBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) throws {
        try store.saveBloodPressureReading(measuredAt: measuredAt, systolic: systolic, diastolic: diastolic, pulse: pulse)
    }

    func deleteBloodPressureReading(id: UUID) throws {
        guard let reading = store.fetchAllBloodPressureReadings().first(where: { $0.id == id }) else {
            throw DiaryRepositoryError.notFound
        }
        try store.deleteBloodPressureReading(reading)
    }

    func deleteAllBloodPressureReadings() throws {
        try store.deleteAllBloodPressureReadings()
    }

    // MARK: - Model Lookup

    /// Scans the full list: the store has no fetch by id, and entries are few.
    private func entryModel(_ id: UUID) throws -> DiaryEntry {
        guard let entry = store.fetchAllDiaryEntries().first(where: { $0.id == id }) else {
            throw DiaryRepositoryError.notFound
        }
        return entry
    }
}
