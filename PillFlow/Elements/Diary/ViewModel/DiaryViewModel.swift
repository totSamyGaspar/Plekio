//
//  DiaryViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//

import SwiftUI
import Combine

@MainActor
final class DiaryViewModel: DiaryViewModelProtocol {
    @Published var entries: [DiaryEntry] = []

    private let dbService: DatabaseServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(dbService: DatabaseServiceProtocol) {
        self.dbService = dbService
        fetchEntries()

        // Diary subscribes to the narrower .diaryDidUpdate channel rather
        // than the app-wide .databaseDidUpdate — otherwise every unrelated
        // write (taking a pill, refilling stock, editing a course) would
        // also trigger a full re-fetch of every diary entry.
        NotificationCenter.default.publisher(for: .diaryDidUpdate)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.fetchEntries() }
            .store(in: &cancellables)
    }

    func fetchEntries() {
        entries = dbService.fetchAllDiaryEntries()
    }

    func deleteEntry(_ entry: DiaryEntry) {
        dbService.deleteDiaryEntry(entry)
        fetchEntries()
    }

    func quickLog(mood: DiaryMood) {
        var draft = DiaryEntryDraft()
        draft.mood = mood
        // The quick-mood chips never show the energy/sleep/water fields, so
        // draft's static defaults for them aren't real input — flag this
        // entry so stats that average those fields exclude it.
        draft.isQuickLog = true
        dbService.saveDiaryEntry(draft: draft)
    }

    // MARK: - Stats

    /// Entries from the last 7 days (today inclusive); falls back to all
    /// entries when nothing was logged in that window.
    private var recentEntries: [DiaryEntry] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let cutoff = Calendar.current.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        let recent = entries.filter { $0.checkInDate >= cutoff }
        return recent.isEmpty ? entries : recent
    }

    /// Non-quick-logged entries only — quick-logged entries carry
    /// DiaryEntryDraft's static defaults for energyLevel/sleepHours/etc.
    /// (never actually seen or entered by the user), so any stat averaging
    /// those specific fields must exclude them or it silently reports
    /// fabricated numbers as real trends. Mood is exempt: quick-logging IS a
    /// genuine mood report, just without the rest of the form.
    private var detailedEntries: [DiaryEntry] {
        entries.filter { !$0.isQuickLog }
    }

    private var recentDetailedEntries: [DiaryEntry] {
        recentEntries.filter { !$0.isQuickLog }
    }

    var avgMoodScore: Double {
        guard !recentEntries.isEmpty else { return 0 }
        return Double(recentEntries.reduce(0) { $0 + $1.moodScore }) / Double(recentEntries.count)
    }

    var avgEnergyLevel: Double {
        guard !recentDetailedEntries.isEmpty else { return 0 }
        return Double(recentDetailedEntries.reduce(0) { $0 + $1.energyLevel }) / Double(recentDetailedEntries.count)
    }

    var totalPhotosLogged: Int {
        entries.reduce(0) { $0 + $1.photoIds.count }
    }

    var avgSleepHours: Double {
        guard !detailedEntries.isEmpty else { return 0 }
        return detailedEntries.reduce(0.0) { $0 + $1.sleepHours } / Double(detailedEntries.count)
    }

    var hasCheckedInToday: Bool {
        todaysEntry != nil
    }

    var todaysEntry: DiaryEntry? {
        entries.first { Calendar.current.isDateInToday($0.checkInDate) }
    }
}

// MARK: - Mock (previews)

final class MockDiaryViewModel: DiaryViewModelProtocol {
    @Published var entries: [DiaryEntry] = []

    var avgMoodScore: Double = 4.0
    var avgEnergyLevel: Double = 3.3
    var totalPhotosLogged: Int = 4
    var avgSleepHours: Double = 7.5
    var hasCheckedInToday: Bool = false
    var todaysEntry: DiaryEntry?

    init() {}

    func fetchEntries() {}
    func deleteEntry(_ entry: DiaryEntry) {}
    func quickLog(mood: DiaryMood) {}
}
