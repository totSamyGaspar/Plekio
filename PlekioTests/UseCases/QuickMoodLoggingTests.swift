//
//  QuickMoodLoggingTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Testing
import Foundation
@testable import Plekio

/// The rule behind the Today card's moods and the widget's: one entry per day.
@MainActor
@Suite("QuickMoodLogging")
struct QuickMoodLoggingTests {

    private func entry(daysAgo: Int) -> DiaryEntry {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return DiaryEntry(
            checkInDate: date,
            moodLabel: DiaryMood.neutral.rawValue,
            moodScore: DiaryMood.neutral.score,
            physicalSummary: "",
            energyLevel: 3,
            discomfortLevel: 0,
            sleepHours: 7,
            sleepQuality: SleepQuality.good.rawValue,
            waterGlasses: 6,
            symptoms: [],
            reflectionNotes: "",
            milestoneTags: [],
            photoIds: [],
            isQuickLog: false
        )
    }

    private func make(_ db: MockDatabaseService, errors: SpyErrorReporter = SpyErrorReporter()) -> QuickMoodLogging {
        QuickMoodLogging(diary: SwiftDataDiaryRepository(store: db), errors: errors, time: SystemTime())
    }

    @Test("With no entry today, a quick log is added with just the mood")
    func addsQuickLog() {
        let db = MockDatabaseService()
        db.diaryEntriesToReturn = [entry(daysAgo: 1)]

        #expect(make(db).log(.great))
        #expect(db.savedDiaryDraft?.mood == .great)
        #expect(db.savedDiaryDraft?.isQuickLog == true)
        #expect(db.updatedDiaryEntry == nil)
    }

    @Test("With an entry today, only its mood changes: no second entry")
    func updatesToday() {
        let db = MockDatabaseService()
        let today = entry(daysAgo: 0)
        db.diaryEntriesToReturn = [entry(daysAgo: 1), today]

        #expect(make(db).log(.exhausted))
        #expect(db.savedDiaryDraft == nil)
        #expect(db.updatedDiaryEntry === today)
        #expect(db.updatedDiaryDraft?.mood == .exhausted)
    }
}
