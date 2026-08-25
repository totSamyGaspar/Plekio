//
//  DiaryViewModelTests.swift
//  PillFlowTests
//
//  Tests for the Diary home screen's derived stats (avgMoodScore,
//  avgEnergyLevel, totalPhotosLogged, avgSleepHours, hasCheckedInToday) and
//  quickLog(mood:).
//

import Testing
import Foundation
@testable import PillFlow

@MainActor
@Suite("DiaryViewModel Tests")
struct DiaryViewModelTests {

    @Test("Stats are zero/false with no entries")
    func testStatsWithNoEntries() async throws {
        let mockDb = MockDatabaseService()
        mockDb.diaryEntriesToReturn = []
        let vm = DiaryViewModel(dbService: mockDb)

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
        let vm = DiaryViewModel(dbService: mockDb)

        #expect(vm.avgMoodScore == 4.0)   // (5 + 3) / 2
        #expect(vm.avgEnergyLevel == 3.0) // (5 + 1) / 2
        #expect(vm.avgSleepHours == 7.0)  // (8 + 6) / 2
        #expect(vm.totalPhotosLogged == 2)
        #expect(vm.hasCheckedInToday == true)
    }

    @Test("Stats fall back to all entries when nothing was logged in the last 7 days")
    func testStatsFallBackWhenNoRecentEntries() async throws {
        let mockDb = MockDatabaseService()
        mockDb.diaryEntriesToReturn = [
            makeEntry(daysAgo: 30, moodScore: 2, energyLevel: 2, sleepHours: 5, photoCount: 1),
        ]
        let vm = DiaryViewModel(dbService: mockDb)

        #expect(vm.avgMoodScore == 2.0)
        #expect(vm.hasCheckedInToday == false)
    }

    @Test("quickLog(mood:) saves a minimal draft with just that mood, flagged as a quick log")
    func testQuickLogSavesMinimalDraft() async throws {
        let mockDb = MockDatabaseService()
        let vm = DiaryViewModel(dbService: mockDb)

        vm.quickLog(mood: .exhausted)

        #expect(mockDb.savedDiaryDraft?.mood == .exhausted)
        #expect(mockDb.savedDiaryDraft?.isQuickLog == true)
    }

    @Test("avgEnergyLevel and avgSleepHours exclude quick-logged entries, but avgMoodScore includes them")
    func testQuickLoggedEntriesExcludedFromEnergyAndSleepAverages() async throws {
        let mockDb = MockDatabaseService()
        mockDb.diaryEntriesToReturn = [
            // A full check-in: real energyLevel/sleepHours.
            makeEntry(daysAgo: 0, moodScore: 4, energyLevel: 2, sleepHours: 6, photoCount: 0),
            // A quick mood log: energyLevel/sleepHours are just
            // DiaryEntryDraft's static defaults (4 and 7.5), never actually
            // entered by the user — must not be averaged in as real data.
            makeEntry(daysAgo: 0, moodScore: 2, energyLevel: 4, sleepHours: 7.5, photoCount: 0, isQuickLog: true),
        ]
        let vm = DiaryViewModel(dbService: mockDb)

        // Energy/sleep averages come from the one detailed entry only.
        #expect(vm.avgEnergyLevel == 2.0)
        #expect(vm.avgSleepHours == 6.0)
        // Mood average legitimately includes both — quick-logging a mood is
        // still a real, user-provided mood report.
        #expect(vm.avgMoodScore == 3.0) // (4 + 2) / 2
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
