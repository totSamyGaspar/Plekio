//
//  DiarySnapshots.swift
//  Plekio
//
//  Diary entries and blood-pressure readings as the diary screens see them:
//  values copied out of the store. Same reasons as CourseSnapshot — a screen
//  holds what was true when it read, and writes go back by id through
//  DiaryRepository.
//

import Foundation

nonisolated struct DiaryEntrySnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let checkInDate: Date
    let moodLabel: String
    let moodScore: Int
    let physicalSummary: String
    let energyLevel: Int
    let discomfortLevel: Int
    let sleepHours: Double
    let sleepQuality: String
    let waterGlasses: Int
    let symptoms: [String]
    let reflectionNotes: String
    let milestoneTags: [String]
    /// Photo files on disk, keyed by these ids — see DiaryEntry.
    let photoIds: [UUID]
    /// From the one-tap mood chips: energy, sleep and water are defaults, not
    /// input, and averages must leave them out — see DiaryEntry.
    let isQuickLog: Bool

    /// Same labels and defaults as DiaryEntry's init, so a preview or a test
    /// builds one the same way.
    init(
        id: UUID = UUID(),
        checkInDate: Date,
        moodLabel: String,
        moodScore: Int,
        physicalSummary: String,
        energyLevel: Int,
        discomfortLevel: Int,
        sleepHours: Double,
        sleepQuality: String,
        waterGlasses: Int,
        symptoms: [String],
        reflectionNotes: String,
        milestoneTags: [String],
        photoIds: [UUID] = [],
        isQuickLog: Bool = false
    ) {
        self.id = id
        self.checkInDate = checkInDate
        self.moodLabel = moodLabel
        self.moodScore = moodScore
        self.physicalSummary = physicalSummary
        self.energyLevel = energyLevel
        self.discomfortLevel = discomfortLevel
        self.sleepHours = sleepHours
        self.sleepQuality = sleepQuality
        self.waterGlasses = waterGlasses
        self.symptoms = symptoms
        self.reflectionNotes = reflectionNotes
        self.milestoneTags = milestoneTags
        self.photoIds = photoIds
        self.isQuickLog = isQuickLog
    }

    /// On the main actor because DiaryMood is — the module defaults to it — and
    /// only views read this.
    @MainActor
    var moodTitle: String {
        guard let mood = DiaryMood(rawValue: moodLabel) else { return moodLabel }
        return String(localized: mood.title)
    }

    var displayCaption: String {
        physicalSummary.isEmpty ? reflectionNotes : physicalSummary
    }
}

nonisolated struct BloodPressureSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let measuredAt: Date
    let systolic: Int
    let diastolic: Int
    let pulse: Int?

    var formattedPressure: String {
        "\(systolic)/\(diastolic)"
    }
}

/// What counts as a plausible reading. One place, asked by the entry form (to
/// enable Save and explain why not) and by BloodPressureLogging (to refuse the
/// write), so the two cannot disagree.
nonisolated enum BloodPressureRules {
    static let systolicRange = 60...300
    static let diastolicRange = 30...200
    static let pulseRange = 30...220

    static func isOrdered(systolic: Int, diastolic: Int) -> Bool {
        systolic > diastolic
    }

    /// Why a reading is not one. Checked in this order, so the form names the
    /// first thing to fix.
    enum Issue: Equatable, Sendable {
        case systolicOutOfRange
        case diastolicOutOfRange
        case pulseOutOfRange
        /// Both numbers in range, but the upper one is not above the lower —
        /// usually the two fields typed the wrong way round.
        case inverted
        /// Measured later than now.
        case inFuture
    }

    /// Nil for a reading that can be saved.
    static func issue(systolic: Int, diastolic: Int, pulse: Int?, measuredAt: Date, now: Date) -> Issue? {
        guard systolicRange.contains(systolic) else { return .systolicOutOfRange }
        guard diastolicRange.contains(diastolic) else { return .diastolicOutOfRange }
        if let pulse, !pulseRange.contains(pulse) { return .pulseOutOfRange }
        guard isOrdered(systolic: systolic, diastolic: diastolic) else { return .inverted }
        guard measuredAt <= now else { return .inFuture }
        return nil
    }
}

// MARK: - Mapping from the store

@MainActor
extension DiaryEntrySnapshot {
    init(_ model: DiaryEntry) {
        self.init(
            id: model.id,
            checkInDate: model.checkInDate,
            moodLabel: model.moodLabel,
            moodScore: model.moodScore,
            physicalSummary: model.physicalSummary,
            energyLevel: model.energyLevel,
            discomfortLevel: model.discomfortLevel,
            sleepHours: model.sleepHours,
            sleepQuality: model.sleepQuality,
            waterGlasses: model.waterGlasses,
            symptoms: model.symptoms,
            reflectionNotes: model.reflectionNotes,
            milestoneTags: model.milestoneTags,
            photoIds: model.photoIds,
            isQuickLog: model.isQuickLog
        )
    }
}

@MainActor
extension BloodPressureSnapshot {
    init(_ model: BloodPressureReading) {
        self.init(
            id: model.id,
            measuredAt: model.measuredAt,
            systolic: model.systolic,
            diastolic: model.diastolic,
            pulse: model.pulse
        )
    }
}
