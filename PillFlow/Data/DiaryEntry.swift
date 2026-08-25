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
    // True when this entry was created via the home screen's one-tap "quick
    // mood" chips rather than the full check-in form — those chips never show
    // energyLevel/sleepHours/sleepQuality/waterGlasses to the user at all, so
    // this entry's values for those fields are just DiaryEntryDraft's static
    // defaults, not anything the user actually reported. Stats that average
    // those specific fields (avgEnergyLevel, avgSleepHours) must exclude
    // quick-logged entries, and any UI displaying them per-entry must hide
    // them here too — otherwise fabricated numbers read as real input.
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
