//
//  DiaryViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 24.08.2026.
//

import SwiftUI
import Combine

@MainActor
final class DiaryViewModel: DiaryViewModelProtocol {

    // MARK: - Properties

    @Published var entries: [DiaryEntrySnapshot] = []

    /// Every entry's photos, newest first. Stored so it is rebuilt once per data
    /// change rather than on every body pass.
    @Published private(set) var photoCheckpoints: [DiaryPhotoCheckpoint] = []

    @Published private(set) var bloodPressureReadings: [BloodPressureSnapshot] = []

    private let diary: any DiaryRepository
    private let errors: any ErrorReporting
    private let time: any TimeSource
    private let bloodPressure: BloodPressureLogging
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    /// `debounce` coalesces bursts of writes; tests pass `.zero` so they need not wait.
    init(
        diary: any DiaryRepository,
        errors: any ErrorReporting,
        changes: DatabaseChangeFeed,
        time: any TimeSource = SystemTime(),
        debounce: RunLoop.SchedulerTimeType.Stride = .milliseconds(300)
    ) {
        self.time = time
        self.diary = diary
        self.errors = errors
        self.bloodPressure = BloodPressureLogging(diary: diary, errors: errors, time: time)
        fetchEntries()

        // Only diary writes; other writes would needlessly re-fetch every entry.
        changes.publisher(for: [.diary])
            .debounce(for: debounce, scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.fetchEntries() }
            .store(in: &cancellables)
    }

    /// Over the SwiftData store — the shape tests use.
    convenience init(
        dbService: any DiaryStoring & BloodPressureStoring & DatabaseChangeSource,
        errors: any ErrorReporting,
        debounce: RunLoop.SchedulerTimeType.Stride = .milliseconds(300)
    ) {
        self.init(
            diary: SwiftDataDiaryRepository(store: dbService),
            errors: errors,
            changes: dbService.changes,
            debounce: debounce
        )
    }

    // MARK: - Actions

    func fetchEntries() {
        entries = diary.allEntries()
        photoCheckpoints = entries.flatMap { entry in
            entry.photoIds.map { DiaryPhotoCheckpoint(photoId: $0, entry: entry) }
        }
        bloodPressureReadings = diary.allBloodPressureReadings()
    }

    func deleteEntry(_ entry: DiaryEntrySnapshot) {
        guard errors.run({ try diary.deleteEntry(id: entry.id) }) else { return }
        fetchEntries()
    }

    func addBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) {
        guard bloodPressure.save(
            measuredAt: measuredAt, systolic: systolic, diastolic: diastolic, pulse: pulse
        ) else { return }
        fetchEntries()
    }

    func deleteBloodPressureReading(_ reading: BloodPressureSnapshot) {
        guard errors.run({
            try diary.deleteBloodPressureReading(id: reading.id)
        }) else { return }
        fetchEntries()
    }

    func deleteAllBloodPressureReadings() {
        guard errors.run({
            try diary.deleteAllBloodPressureReadings()
        }) else { return }
        fetchEntries()
    }

    func quickLog(mood: DiaryMood) {
        // One entry per day: update today's instead of adding a duplicate.
        if let existing = todaysEntry {
            var draft = DiaryEntryDraft(from: existing)
            draft.mood = mood
            guard errors.run({
                try diary.updateEntry(id: existing.id, with: draft)
            }) else { return }
            fetchEntries()
            return
        }

        var draft = DiaryEntryDraft()
        draft.mood = mood
        // Energy/sleep/water are defaults, not user input; stats must exclude them.
        draft.isQuickLog = true

        guard errors.run({ try diary.saveEntry(draft) }) else { return }
        fetchEntries()
    }

    // MARK: - Stats

    /// Entries from the last 7 days (today inclusive); falls back to all
    /// entries when nothing was logged in that window.
    private var recentEntries: [DiaryEntrySnapshot] {
        let calendar = time.calendar
        let startOfToday = calendar.startOfDay(for: time.now)
        let cutoff = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        let recent = entries.filter { $0.checkInDate >= cutoff }
        return recent.isEmpty ? entries : recent
    }

    /// Excludes quick logs, whose energy/sleep values are defaults, not input.
    /// Mood averages still use all entries: a quick log is a real mood report.
    private var recentDetailedEntries: [DiaryEntrySnapshot] {
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

    /// Same 7-day window as mood and energy, so the stat tiles are comparable.
    var avgSleepHours: Double {
        guard !recentDetailedEntries.isEmpty else { return 0 }
        return recentDetailedEntries.reduce(0.0) { $0 + $1.sleepHours } / Double(recentDetailedEntries.count)
    }

    var hasCheckedInToday: Bool {
        todaysEntry != nil
    }

    var todaysEntry: DiaryEntrySnapshot? {
        let now = time.now
        return entries.first { time.calendar.isDate($0.checkInDate, inSameDayAs: now) }
    }
}

// MARK: - Mock

#if DEBUG
final class MockDiaryViewModel: DiaryViewModelProtocol {
    @Published var entries: [DiaryEntrySnapshot] = []
    @Published private(set) var photoCheckpoints: [DiaryPhotoCheckpoint] = []
    @Published private(set) var bloodPressureReadings: [BloodPressureSnapshot] = []

    var avgMoodScore: Double = 4.0
    var avgEnergyLevel: Double = 3.3
    var totalPhotosLogged: Int = 4
    var avgSleepHours: Double = 7.5
    var hasCheckedInToday: Bool = false
    var todaysEntry: DiaryEntrySnapshot?

    init() {}

    func fetchEntries() {}
    func deleteEntry(_ entry: DiaryEntrySnapshot) {}
    func quickLog(mood: DiaryMood) {}
    func addBloodPressureReading(measuredAt: Date, systolic: Int, diastolic: Int, pulse: Int?) {}
    func deleteBloodPressureReading(_ reading: BloodPressureSnapshot) {}
    func deleteAllBloodPressureReadings() {}
}
#endif
