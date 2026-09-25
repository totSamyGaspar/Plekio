//
//  DiaryViewModelTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.08.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DiaryViewModel Tests")
struct DiaryViewModelTests {

    // MARK: - Refresh

    @Test("экран дневника перечитывается на запись дневника и не реагирует на дозы")
    func refreshesOnDiaryWritesOnly() async throws {
        let mockDb = MockDatabaseService()
        let vm = DiaryViewModel(dbService: mockDb, errors: SpyErrorReporter())
        #expect(vm.entries.isEmpty)

        mockDb.diaryEntriesToReturn = [makeEntry(daysAgo: 0, moodScore: 4, energyLevel: 4, sleepHours: 7, photoCount: 0)]

        // Wait past the 300 ms debounce.
        mockDb.changes.send([.doses])
        try await Task.sleep(for: .milliseconds(500))
        #expect(vm.entries.isEmpty)

        mockDb.changes.send([.diary])
        for _ in 0..<40 where vm.entries.isEmpty {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(vm.entries.count == 1)
    }

    // MARK: - Stats

    @Test("Stats are zero/false with no entries")
    func testStatsWithNoEntries() async throws {
        let mockDb = MockDatabaseService()
        mockDb.diaryEntriesToReturn = []
        let vm = DiaryViewModel(dbService: mockDb, errors: SpyErrorReporter())

        #expect(vm.avgMoodScore == 0)
        #expect(vm.avgEnergyLevel == 0)
        #expect(vm.totalPhotosLogged == 0)
        #expect(vm.avgSleepHours == 0)
        #expect(vm.hasCheckedInToday == false)
    }

    @Test("avgMoodScore and avgEnergyLevel average today's recent entries")
    func testAveragesOverRecentEntries() async throws {
        let mockDb = MockDatabaseService()
        mockDb.diaryEntriesToReturn = [
            makeEntry(daysAgo: 0, moodScore: 5, energyLevel: 5, sleepHours: 8, photoCount: 2),
            makeEntry(daysAgo: 1, moodScore: 3, energyLevel: 1, sleepHours: 6, photoCount: 0),
        ]
        let vm = DiaryViewModel(dbService: mockDb, errors: SpyErrorReporter())

        #expect(vm.avgMoodScore == 4.0)
        #expect(vm.avgEnergyLevel == 3.0)
        #expect(vm.avgSleepHours == 7.0)
        #expect(vm.totalPhotosLogged == 2)
        #expect(vm.hasCheckedInToday == true)
    }

    @Test("Stats fall back to all entries when nothing was logged in the last 7 days")
    func testStatsFallBackWhenNoRecentEntries() async throws {
        let mockDb = MockDatabaseService()
        mockDb.diaryEntriesToReturn = [
            makeEntry(daysAgo: 30, moodScore: 2, energyLevel: 2, sleepHours: 5, photoCount: 1),
        ]
        let vm = DiaryViewModel(dbService: mockDb, errors: SpyErrorReporter())

        #expect(vm.avgMoodScore == 2.0)
        #expect(vm.hasCheckedInToday == false)
    }

    // MARK: - Quick log

    @Test("quickLog(mood:) saves a minimal draft with just that mood, flagged as a quick log")
    func testQuickLogSavesMinimalDraft() async throws {
        let mockDb = MockDatabaseService()
        let vm = DiaryViewModel(dbService: mockDb, errors: SpyErrorReporter())

        vm.quickLog(mood: .exhausted)

        #expect(mockDb.savedDiaryDraft?.mood == .exhausted)
        #expect(mockDb.savedDiaryDraft?.isQuickLog == true)
    }

    @Test("quickLog обновляет сегодняшнюю запись, а не создаёт вторую")
    func testQuickLogUpdatesTodaysEntryInsteadOfDuplicating() async throws {
        let mockDb = MockDatabaseService()
        let today = makeEntry(daysAgo: 0, moodScore: 3, energyLevel: 3, sleepHours: 7, photoCount: 0)
        mockDb.diaryEntriesToReturn = [today]

        let vm = DiaryViewModel(dbService: mockDb, errors: SpyErrorReporter())
        vm.quickLog(mood: .great)

        // One entry per day: a second would be hidden from editing but counted in averages.
        #expect(mockDb.savedDiaryDraft == nil)
        #expect(mockDb.updatedDiaryEntry === today)
        #expect(mockDb.updatedDiaryDraft?.mood == .great)
    }

    @Test("avgEnergyLevel and avgSleepHours exclude quick-logged entries, but avgMoodScore includes them")
    func testQuickLoggedEntriesExcludedFromEnergyAndSleepAverages() async throws {
        let mockDb = MockDatabaseService()
        mockDb.diaryEntriesToReturn = [
            makeEntry(daysAgo: 0, moodScore: 4, energyLevel: 2, sleepHours: 6, photoCount: 0),
            // Quick log: energy/sleep are draft defaults, not user data.
            makeEntry(daysAgo: 0, moodScore: 2, energyLevel: 4, sleepHours: 7.5, photoCount: 0, isQuickLog: true),
        ]
        let vm = DiaryViewModel(dbService: mockDb, errors: SpyErrorReporter())

        #expect(vm.avgEnergyLevel == 2.0)
        #expect(vm.avgSleepHours == 6.0)
        // A quick-logged mood is still real data.
        #expect(vm.avgMoodScore == 3.0)
    }

    // MARK: - Comparison pair

    @Test("без выбора сравниваются самое раннее и самое позднее фото")
    func testComparisonPairFallsBackToEarliestAndLatest() async throws {
        let mockDb = MockDatabaseService()
        mockDb.diaryEntriesToReturn = [
            makeEntry(daysAgo: 10, moodScore: 4, energyLevel: 4, sleepHours: 8, photoCount: 1),
            makeEntry(daysAgo: 5, moodScore: 4, energyLevel: 4, sleepHours: 8, photoCount: 1),
            makeEntry(daysAgo: 0, moodScore: 4, energyLevel: 4, sleepHours: 8, photoCount: 1),
        ]
        let vm = DiaryViewModel(dbService: mockDb, errors: SpyErrorReporter())
        let byDate = vm.photoCheckpoints.sorted { $0.entry.checkInDate < $1.entry.checkInDate }

        let pair = try #require(vm.comparisonPair(for: []))

        #expect(pair.before == byDate.first?.id)
        #expect(pair.after == byDate.last?.id)
    }

    @Test("два выбранных сравниваются от старого к новому, в каком бы порядке их ни отметили")
    func testComparisonPairOrdersSelectionByDate() async throws {
        let mockDb = MockDatabaseService()
        mockDb.diaryEntriesToReturn = [
            makeEntry(daysAgo: 10, moodScore: 4, energyLevel: 4, sleepHours: 8, photoCount: 1),
            makeEntry(daysAgo: 5, moodScore: 4, energyLevel: 4, sleepHours: 8, photoCount: 1),
            makeEntry(daysAgo: 0, moodScore: 4, energyLevel: 4, sleepHours: 8, photoCount: 1),
        ]
        let vm = DiaryViewModel(dbService: mockDb, errors: SpyErrorReporter())
        let byDate = vm.photoCheckpoints.sorted { $0.entry.checkInDate < $1.entry.checkInDate }
        let older = byDate[0].id
        let newer = byDate[1].id

        // Ticked newest first on purpose.
        let pair = try #require(vm.comparisonPair(for: [newer, older]))

        #expect(pair.before == older)
        #expect(pair.after == newer)
    }

    @Test("выбор, указывающий на удалённое фото, откатывается к раннему и позднему")
    func testComparisonPairIgnoresStaleSelection() async throws {
        let mockDb = MockDatabaseService()
        mockDb.diaryEntriesToReturn = [
            makeEntry(daysAgo: 10, moodScore: 4, energyLevel: 4, sleepHours: 8, photoCount: 1),
            makeEntry(daysAgo: 0, moodScore: 4, energyLevel: 4, sleepHours: 8, photoCount: 1),
        ]
        let vm = DiaryViewModel(dbService: mockDb, errors: SpyErrorReporter())
        let byDate = vm.photoCheckpoints.sorted { $0.entry.checkInDate < $1.entry.checkInDate }

        let pair = try #require(vm.comparisonPair(for: [byDate[1].id, UUID()]))

        #expect(pair.before == byDate.first?.id)
        #expect(pair.after == byDate.last?.id)
    }

    @Test("сравнивать нечего, пока фото меньше двух")
    func testComparisonPairIsNilWithFewerThanTwoPhotos() async throws {
        let mockDb = MockDatabaseService()
        mockDb.diaryEntriesToReturn = [
            makeEntry(daysAgo: 0, moodScore: 4, energyLevel: 4, sleepHours: 8, photoCount: 1),
        ]
        let vm = DiaryViewModel(dbService: mockDb, errors: SpyErrorReporter())

        #expect(vm.comparisonPair(for: []) == nil)
    }

    // MARK: - Helpers

    private func makeEntry(
        daysAgo: Int, moodScore: Int, energyLevel: Int, sleepHours: Double, photoCount: Int,
        isQuickLog: Bool = false
    ) -> DiaryEntry {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return DiaryEntry(
            checkInDate: date,
            moodLabel: DiaryMood.good.rawValue,
            moodScore: moodScore,
            physicalSummary: "",
            energyLevel: energyLevel,
            discomfortLevel: 0,
            sleepHours: sleepHours,
            sleepQuality: SleepQuality.good.rawValue,
            waterGlasses: 6,
            symptoms: [],
            reflectionNotes: "",
            milestoneTags: [],
            photoIds: (0..<photoCount).map { _ in UUID() },
            isQuickLog: isQuickLog
        )
    }
}
