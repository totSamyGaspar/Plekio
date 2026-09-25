//
//  DiaryRepositoryTests.swift
//  PlekioTests
//
//  The boundary between the store and the diary screens: models in, snapshots
//  out, writes by id.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DiaryRepository Tests")
struct DiaryRepositoryTests {

    private func entry(mood: Int = 4) -> DiaryEntry {
        DiaryEntry(
            checkInDate: Date(), moodLabel: DiaryMood.good.rawValue, moodScore: mood,
            physicalSummary: "", energyLevel: 3, discomfortLevel: 0, sleepHours: 7,
            sleepQuality: SleepQuality.good.rawValue, waterGlasses: 4,
            symptoms: [], reflectionNotes: "Заметка", milestoneTags: [],
            photoIds: [UUID()], isQuickLog: true
        )
    }

    @Test("снимок записи переносит все поля, включая фото и флаг быстрой записи")
    func entrySnapshotCopiesEveryField() throws {
        let db = MockDatabaseService()
        let model = entry()
        db.diaryEntriesToReturn = [model]

        let snapshot = try #require(SwiftDataDiaryRepository(store: db).allEntries().first)

        #expect(snapshot.id == model.id)
        #expect(snapshot.photoIds == model.photoIds)
        #expect(snapshot.isQuickLog)
        #expect(snapshot.displayCaption == "Заметка")
    }

    @Test("правка и удаление находят запись по id")
    func writesFindTheEntryById() throws {
        let db = MockDatabaseService()
        let model = entry()
        db.diaryEntriesToReturn = [model]
        let repository = SwiftDataDiaryRepository(store: db)

        var draft = DiaryEntryDraft(from: DiaryEntrySnapshot(model))
        draft.reflectionNotes = "Новая"
        try repository.updateEntry(id: model.id, with: draft)
        try repository.deleteEntry(id: model.id)

        #expect(db.updatedDiaryEntry === model)
        #expect(db.updatedDiaryDraft?.reflectionNotes == "Новая")
        #expect(db.deletedDiaryEntry === model)
    }

    @Test("запись по id удалённой записи — ошибка, а не тихий пропуск")
    func writeToMissingEntryThrows() {
        let repository = SwiftDataDiaryRepository(store: MockDatabaseService())

        #expect(throws: DiaryRepositoryError.self) {
            try repository.deleteEntry(id: UUID())
        }
        #expect(throws: DiaryRepositoryError.self) {
            try repository.deleteBloodPressureReading(id: UUID())
        }
    }

    @Test("давление: снимок и удаление по id")
    func bloodPressureByIdAndSnapshot() throws {
        let db = MockDatabaseService()
        let reading = BloodPressureReading(measuredAt: Date(), systolic: 120, diastolic: 80, pulse: 70)
        db.bloodPressureReadingsToReturn = [reading]
        let repository = SwiftDataDiaryRepository(store: db)

        #expect(repository.allBloodPressureReadings().first?.formattedPressure == "120/80")

        try repository.deleteBloodPressureReading(id: reading.id)
        #expect(db.deletedBloodPressureReading === reading)
    }
}
