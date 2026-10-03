//
//  DataErasingTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 03.10.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("Manage your data: erasing")
struct DataErasingTests {

    // MARK: - Helpers

    private let photos = FakePhotoStore()
    private let settings = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    /// Today is 15 June 2026: a course ending before it is finished.
    private let db: DatabaseService
    private let erasing: DataErasing

    init() {
        db = DatabaseService(
            inMemoryForTesting: true,
            photos: photos,
            errors: SpyErrorReporter(),
            time: FixedTime(testDate(2026, 6, 15, 12))
        )
        erasing = DataErasing(store: db, settings: settings, photos: photos)
    }

    /// A course with one medication that has a photo; returns the medication id.
    @discardableResult
    private func addCourse(_ name: String, ending end: Date) throws -> UUID {
        var draft = MedicationDraft()
        draft.name = name
        draft.medicationImageData = Data([0x01])
        try db.saveCourse(name: name, startDate: testDate(2026, 6, 1), endDate: end, drafts: [draft])
        return draft.id
    }

    private func addDiary() throws {
        var entry = DiaryEntryDraft()
        entry.photos = [Data([0x02])]
        try db.saveDiaryEntry(draft: entry)
        try db.saveBloodPressureReading(measuredAt: testDate(2026, 6, 10), systolic: 120, diastolic: 80, pulse: nil)
    }

    // MARK: - Tests

    @Test("The summary counts what each action would delete")
    func summaryCounts() throws {
        try addCourse("Finished", ending: testDate(2026, 6, 10))
        try addCourse("Running", ending: testDate(2026, 6, 30))
        try addDiary()

        #expect(erasing.summary() == StoredDataSummary(diaryRecords: 2, finishedCourses: 1, courses: 2))
    }

    @Test("Deleting the diary removes entries, their photos and blood pressure; courses stay")
    func eraseDiary() throws {
        try addCourse("Running", ending: testDate(2026, 6, 30))
        try addDiary()
        let photoId = try #require(db.fetchAllDiaryEntries().first?.photoIds.first)

        try erasing.eraseDiary()

        #expect(db.fetchAllDiaryEntries().isEmpty)
        #expect(db.fetchAllBloodPressureReadings().isEmpty)
        #expect(photos.saved[photoId] == nil)
        #expect(db.fetchAllCourses().count == 1)
    }

    @Test("Clearing course history removes only finished courses and their photos")
    func eraseCourseHistory() throws {
        let finished = try addCourse("Finished", ending: testDate(2026, 6, 10))
        let running = try addCourse("Running", ending: testDate(2026, 6, 15))

        try erasing.eraseCourseHistory()

        #expect(db.fetchAllCourses().map(\.name) == ["Running"])
        #expect(photos.saved[finished] == nil)
        #expect(photos.saved[running] != nil)
    }

    @Test("Deleting everything removes all records, photos and the profile")
    func eraseEverything() throws {
        try addCourse("Running", ending: testDate(2026, 6, 30))
        try addDiary()
        let avatarId = UUID()
        _ = photos.saveToDisk(Data([0x03]), for: avatarId)
        settings.userProfile = UserProfile(name: "Anna", avatarId: avatarId)

        try erasing.eraseEverything()

        #expect(erasing.summary().isEmpty)
        #expect(photos.saved.isEmpty)
        #expect(settings.userProfile == .empty)
    }
}
