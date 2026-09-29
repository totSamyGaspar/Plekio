//
//  DiaryEntry.swift
//  Plekio
//
//  Created by Edward Gasparian on 24.08.2026.
//

import Foundation
import SwiftData

// MARK: - DiaryEntry

nonisolated extension SchemaV1 {

    /// `nonisolated`: BackgroundReader reads it on a background context.
    @Model
    nonisolated final class DiaryEntry {

        // MARK: - Properties

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
        /// Ids of photo files stored on disk by ImageCache.
        var photoIds: [UUID]
        /// From a one-tap mood chip: energy, sleep and water are defaults, not user
        /// input, so averages and per-entry UI must exclude quick logs.
        var isQuickLog: Bool

        // MARK: - Init

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
}

// MARK: - Display

nonisolated extension DiaryEntry {
    var moodTitle: String {
        guard let mood = DiaryMood(rawValue: moodLabel) else { return moodLabel }
        return String(localized: mood.title)
    }

    var displayCaption: String {
        physicalSummary.isEmpty ? reflectionNotes : physicalSummary
    }
}
