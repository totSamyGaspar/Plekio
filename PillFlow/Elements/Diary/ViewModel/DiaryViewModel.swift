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

    /// Every entry's photos as checkpoints, newest first (entries are already
    /// sorted by descending date). This used to be a computed property on the
    /// view, so the flatMap over all entries and photos re-ran several times per
    /// body pass; now it is recomputed once per data change.
    @Published private(set) var photoCheckpoints: [DiaryPhotoCheckpoint] = []

    @Published private(set) var bloodPressureReadings: [BloodPressureReading] = []

    private let dbService: DatabaseServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(dbService: DatabaseServiceProtocol) {
        self.dbService = dbService
        fetchEntries()

        // Only diary writes: otherwise every unrelated write — taking a pill,
        // refilling stock, editing a course — would re-fetch every diary entry
        // and rebuild the photo checkpoints with it.
        NotificationCenter.default.publisher(forDatabaseChanges: [.diary])
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.fetchEntries() }
            .store(in: &cancellables)
    }

    func fetchEntries() {
        entries = dbService.fetchAllDiaryEntries()
        photoCheckpoints = entries.flatMap { entry in
            entry.photoIds.map { DiaryPhotoCheckpoint(photoId: $0, entry: entry) }
        }
        // Fetched alongside the entries because both answer the same .diary
        // change — a separate path would mean two subscriptions for one screen.
        bloodPressureReadings = dbService.fetchAllBloodPressureReadings()
    }

    func deleteEntry(_ entry: DiaryEntry) {
        guard AppErrorPresenter.shared.run({ try dbService.deleteDiaryEntry(entry) }) else { return }
        fetchEntries()
    }

    func addBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) {
        guard AppErrorPresenter.shared.run({
            try dbService.saveBloodPressureReading(
                measuredAt: measuredAt, systolic: systolic, diastolic: diastolic, pulse: pulse
            )
        }) else { return }
        fetchEntries()
    }

    func deleteBloodPressureReading(_ reading: BloodPressureReading) {
        guard AppErrorPresenter.shared.run({
            try dbService.deleteBloodPressureReading(reading)
        }) else { return }
        fetchEntries()
    }

    func quickLog(mood: DiaryMood) {
        // Update today's entry rather than adding a second one. Without this guard
        // duplicates piled up: todaysEntry and "Edit Entry" only ever saw the first
        // of them, while the averages counted them all.
        if let existing = todaysEntry {
            var draft = DiaryEntryDraft(from: existing)
            draft.mood = mood
            guard AppErrorPresenter.shared.run({
                try dbService.updateDiaryEntry(existing, with: draft)
            }) else { return }
            fetchEntries()
            return
        }

        var draft = DiaryEntryDraft()
        draft.mood = mood
        // The quick-mood chips never show the energy/sleep/water fields, so
        // draft's static defaults for them aren't real input — flag this
        // entry so stats that average those fields exclude it.
        draft.isQuickLog = true

        guard AppErrorPresenter.shared.run({ try dbService.saveDiaryEntry(draft: draft) }) else { return }
        fetchEntries()
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

    /// Same 7-day window as mood and energy. Sleep used to be averaged over all
    /// time, even though the four stat tiles share one grid and read as
    /// comparable numbers.
    var avgSleepHours: Double {
        guard !recentDetailedEntries.isEmpty else { return 0 }
        return recentDetailedEntries.reduce(0.0) { $0 + $1.sleepHours } / Double(recentDetailedEntries.count)
    }

    var hasCheckedInToday: Bool {
        todaysEntry != nil
    }

    var todaysEntry: DiaryEntry? {
        entries.first { Calendar.current.isDateInToday($0.checkInDate) }
    }
}

// MARK: - Mock (previews)

#if DEBUG
final class MockDiaryViewModel: DiaryViewModelProtocol {
    @Published var entries: [DiaryEntry] = []
    @Published private(set) var photoCheckpoints: [DiaryPhotoCheckpoint] = []
    @Published private(set) var bloodPressureReadings: [BloodPressureReading] = []

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
    func addBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) {}
    func deleteBloodPressureReading(_ reading: BloodPressureReading) {}
}
#endif
