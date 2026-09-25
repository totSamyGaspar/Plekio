//
//  DiarySnapshots.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - DiaryEntrySnapshot

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
    /// Ids of photo files on disk — see DiaryEntry.
    let photoIds: [UUID]
    /// Energy, sleep and water are defaults, not input: exclude from averages.
    let isQuickLog: Bool

    /// Mirrors DiaryEntry's init labels and defaults.
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

    /// Main actor because DiaryMood is.
    @MainActor
    var moodTitle: String {
        guard let mood = DiaryMood(rawValue: moodLabel) else { return moodLabel }
        return String(localized: mood.title)
    }

    var displayCaption: String {
        physicalSummary.isEmpty ? reflectionNotes : physicalSummary
    }
}

// MARK: - BloodPressureSnapshot

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

// MARK: - BloodPressureRules

/// Plausible-reading rules shared by the entry form and BloodPressureLogging.
nonisolated enum BloodPressureRules {
    static let systolicRange = 60...300
    static let diastolicRange = 30...200
    static let pulseRange = 30...220

    static func isOrdered(systolic: Int, diastolic: Int) -> Bool {
        systolic > diastolic
    }

    /// Checked in declaration order, so the form names the first thing to fix.
    enum Issue: Equatable, Sendable {
        case systolicOutOfRange
        case diastolicOutOfRange
        case pulseOutOfRange
        /// Systolic not above diastolic — usually fields swapped.
        case inverted
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
