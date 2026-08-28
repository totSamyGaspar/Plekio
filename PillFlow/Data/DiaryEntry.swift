//
//  DiaryEntry.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//

import Foundation
import SwiftData

@Model
final class DiaryEntry {
    @Attribute(.unique) var id: UUID
    var checkInDate: Date
    var moodLabel: String
    var moodScore: Int
    var physicalSummary: String
    var energyLevel: Int
    var discomfortLevel: Int
    var sleepHours: Double
    var sleepQuality: String
    var waterGlasses: Int
    var symptoms: [String]
    var reflectionNotes: String
    var milestoneTags: [String]
    // Photos are stored on disk via ImageCache (same approach as MedicationItem's
    // photo — see ImageCache.swift), keyed by the ids in this array, rather than
    // as blobs on the model.
    var photoIds: [UUID]
    // True when the entry came from the home screen's one-tap "quick mood" chips
    // instead of the full check-in form. Those chips never ask for energy, sleep or
    // water, so those fields hold DiaryEntryDraft's defaults, not user input:
    // averages over them and per-entry UI must exclude quick logs, or the
    // fabricated numbers read as something the user actually reported.
    var isQuickLog: Bool

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
}

extension DiaryEntry {
    var moodTitle: String {
        guard let mood = DiaryMood(rawValue: moodLabel) else { return moodLabel }
        return String(localized: mood.title)
    }

    var displayCaption: String {
        physicalSummary.isEmpty ? reflectionNotes : physicalSummary
    }
}
