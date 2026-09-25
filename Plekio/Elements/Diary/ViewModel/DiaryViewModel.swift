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
    @Published var entries: [DiaryEntrySnapshot] = []
    
    /// Every entry's photos as checkpoints, newest first (entries are already
    /// sorted by descending date). Stored rather than computed on the view: a
    /// flatMap over every entry and photo re-runs several times per body pass,
    /// where here it is recomputed once per data change.
    @Published private(set) var photoCheckpoints: [DiaryPhotoCheckpoint] = []
    
    @Published private(set) var bloodPressureReadings: [BloodPressureSnapshot] = []
    
    private let diary: any DiaryRepository
    private let errors: any ErrorReporting
    private let time: any TimeSource
    private let bloodPressure: BloodPressureLogging
    private var cancellables = Set<AnyCancellable>()
    
    init(diary: any DiaryRepository, errors: any ErrorReporting, changes: DatabaseChangeFeed, time: any TimeSource = SystemTime()) {
        self.time = time
        self.diary = diary
        self.errors = errors
        // Built here from what the screen already has: stateless, and the same
        // rules as the reminder's form, which gets its own from AppDependencies.
        self.bloodPressure = BloodPressureLogging(diary: diary, errors: errors, time: time)
        fetchEntries()
        
        // Only diary writes: otherwise every unrelated write — taking a pill,
        // refilling stock, editing a course — would re-fetch every diary entry
        // and rebuild the photo checkpoints with it.
        changes.publisher(for: [.diary])
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.fetchEntries() }
            .store(in: &cancellables)
    }

    /// Over the SwiftData store — the shape tests use.
    convenience init(dbService: any DiaryStoring & BloodPressureStoring & DatabaseChangeSource, errors: any ErrorReporting) {
        self.init(diary: SwiftDataDiaryRepository(store: dbService), errors: errors, changes: dbService.changes)
    }
    
    func fetchEntries() {
        entries = diary.allEntries()
        photoCheckpoints = entries.flatMap { entry in
            entry.photoIds.map { DiaryPhotoCheckpoint(photoId: $0, entry: entry) }
        }
        // Fetched alongside the entries because both answer the same .diary
        // change — a separate path would mean two subscriptions for one screen.
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
        // Update today's entry rather than adding a second one. Without this guard
        // duplicates piled up: todaysEntry and "Edit Entry" only ever saw the first
        // of them, while the averages counted them all.
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
        // The quick-mood chips never show the energy/sleep/water fields, so
        // draft's static defaults for them aren't real input — flag this
        // entry so stats that average those fields exclude it.
        draft.isQuickLog = true
        
        guard errors.run({ try diary.saveEntry(draft) }) else { return }
        fetchEntries()
    }
    
    // MARK: - Stats
    
    /// Entries from the last 7 days (today inclusive); falls back to all
    /// entries when nothing was logged in that window.
    private var recentEntries: [DiaryEntrySnapshot] {
        let startOfToday = Calendar.current.startOfDay(for: time.now)
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
    
    /// Same 7-day window as mood and energy: the four stat tiles share one grid
    /// and read as comparable numbers, so they must cover the same period.
    var avgSleepHours: Double {
        guard !recentDetailedEntries.isEmpty else { return 0 }
        return recentDetailedEntries.reduce(0.0) { $0 + $1.sleepHours } / Double(recentDetailedEntries.count)
    }
    
    var hasCheckedInToday: Bool {
        todaysEntry != nil
    }
    
    var todaysEntry: DiaryEntrySnapshot? {
        let now = time.now
        return entries.first { Calendar.current.isDate($0.checkInDate, inSameDayAs: now) }
    }
}

// MARK: - Mock (previews)

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
