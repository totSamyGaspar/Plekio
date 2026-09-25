//
//  DiaryEntryDraft.swift
//  Plekio
//
//  Created by Edward Gasparian on 24.08.2026.
//

import Foundation

// MARK: - DiaryMood

nonisolated enum DiaryMood: String, CaseIterable, Identifiable {
    case great = "Great"
    case good = "Good"
    case neutral = "Neutral"
    case downLow = "Down / Low"
    case stressed = "Stressed"
    case exhausted = "Exhausted"
    case inPain = "In Pain"

    var id: String { rawValue }

    /// Display label. `rawValue` is the stored key and must never change or be localized.
    var title: LocalizedStringResource {
        switch self {
        case .great:     return "Great"
        case .good:      return "Good"
        case .neutral:   return "Neutral"
        case .downLow:   return "Down / Low"
        case .stressed:  return "Stressed"
        case .exhausted: return "Exhausted"
        case .inPain:    return "In Pain"
        }
    }

    var emoji: String {
        switch self {
        case .great:     return "⭐"
        case .good:      return "😊"
        case .neutral:   return "😐"
        case .downLow:   return "😔"
        case .stressed:  return "⚡"
        case .exhausted: return "😴"
        case .inPain:    return "🩹"
        }
    }

    /// 1–5 score; several negative moods intentionally share 2.
    var score: Int {
        switch self {
        case .great:     return 5
        case .good:      return 4
        case .neutral:   return 3
        case .downLow:   return 2
        case .stressed:  return 2
        case .exhausted: return 2
        case .inPain:    return 1
        }
    }
}

// MARK: - SleepQuality

enum SleepQuality: String, CaseIterable, Identifiable {
    case poor = "P"
    case fair = "F"
    case good = "G"
    case excellent = "E"

    var id: String { rawValue }

    /// Localized initial for compact buttons; `rawValue` is a storage key.
    var initial: LocalizedStringResource {
        switch self {
        case .poor:      return "P"
        case .fair:      return "F"
        case .good:      return "G"
        case .excellent: return "E"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .poor:      return "Poor"
        case .fair:      return "Fair"
        case .good:      return "Good"
        case .excellent: return "Excellent"
        }
    }
}

// MARK: - DiaryEntryDraft

/// In-progress state of the Diary check-in form.
struct DiaryEntryDraft: Identifiable, Equatable {

    // MARK: - Ranges

    // Numeric bounds are enforced here, not in the controls that edit them.
    static let energyLevelRange = 1...5
    static let discomfortLevelRange = 0...10
    static let sleepHoursRange = 0.0...24.0
    static let waterGlassesRange = 0...50

    // MARK: - Fields

    var id = UUID()
    var checkInDate: Date = Date()
    var mood: DiaryMood = .good
    var physicalSummary: String = ""

    // didSet doesn't run during init, so init(from:) clamps its arguments too.
    var energyLevel: Int = 4 {
        didSet { energyLevel = Self.energyLevelRange.clamping(energyLevel) }
    }
    var discomfortLevel: Int = 0 {
        didSet { discomfortLevel = Self.discomfortLevelRange.clamping(discomfortLevel) }
    }
    var sleepHours: Double = 7.5 {
        didSet { sleepHours = Self.sleepHoursRange.clamping(sleepHours) }
    }
    var sleepQuality: SleepQuality = .good
    var waterGlasses: Int = 6 {
        didSet { waterGlasses = Self.waterGlassesRange.clamping(waterGlasses) }
    }
    var symptoms: [String] = []
    var reflectionNotes: String = ""
    var milestoneTags: [String] = []
    /// JPEG bytes; written to disk via ImageCache only on save.
    var photos: [Data] = []
    /// Set for one-tap mood entries — see DiaryEntrySnapshot.isQuickLog.
    var isQuickLog: Bool = false
    /// True only when the user added/removed a photo (not on preload); lets saves
    /// skip rewriting photo files on disk.
    var photosModified: Bool = false
}

// MARK: - DiaryEntryDraft descriptions and mapping

extension DiaryEntryDraft {

    var energyDescription: LocalizedStringResource {
        switch energyLevel {
        case ..<2: return "Low Energy"
        case 2...3: return "Moderate Energy"
        default: return "High Energy"
        }
    }

    var discomfortDescription: LocalizedStringResource {
        switch discomfortLevel {
        case 0:     return "Zero Pain"
        case 1...3: return "Mild"
        case 4...6: return "Manageable"
        default:    return "Severe"
        }
    }

    init(from entry: DiaryEntrySnapshot) {
        self.init(
            id: entry.id,
            checkInDate: entry.checkInDate,
            mood: DiaryMood(rawValue: entry.moodLabel) ?? .good,
            physicalSummary: entry.physicalSummary,
            energyLevel: Self.energyLevelRange.clamping(entry.energyLevel),
            discomfortLevel: Self.discomfortLevelRange.clamping(entry.discomfortLevel),
            sleepHours: Self.sleepHoursRange.clamping(entry.sleepHours),
            sleepQuality: SleepQuality(rawValue: entry.sleepQuality) ?? .good,
            waterGlasses: Self.waterGlassesRange.clamping(entry.waterGlasses),
            symptoms: entry.symptoms,
            reflectionNotes: entry.reflectionNotes,
            milestoneTags: entry.milestoneTags,
            photos: [],
            isQuickLog: entry.isQuickLog,
            photosModified: false
        )
    }
}

// MARK: - DiarySymptomOptions

/// Stored keys are English; `title(for:)` gives the localized label.
enum DiarySymptomOptions {
    static let all = [
        "Headache", "Fatigue", "Brain Fog", "Mild Nausea", "Muscle Tension",
        "Joint Stiffness", "Dizziness", "Restlessness", "Digestive Discomfort",
        "Insomnia", "Dry Mouth", "Elevated Heartbeat",
    ]

    private static let titles: [String: LocalizedStringResource] = [
        "Headache": "Headache",
        "Fatigue": "Fatigue",
        "Brain Fog": "Brain Fog",
        "Mild Nausea": "Mild Nausea",
        "Muscle Tension": "Muscle Tension",
        "Joint Stiffness": "Joint Stiffness",
        "Dizziness": "Dizziness",
        "Restlessness": "Restlessness",
        "Digestive Discomfort": "Digestive Discomfort",
        "Insomnia": "Insomnia",
        "Dry Mouth": "Dry Mouth",
        "Elevated Heartbeat": "Elevated Heartbeat",
    ]

    static func title(for key: String) -> String {
        guard let resource = titles[key] else { return key }
        return String(localized: resource)
    }
}

// MARK: - DiaryMilestoneOptions

enum DiaryMilestoneOptions {
    static let all = [
        "Day 14 Milestone", "Consistent Routine", "Morning Walk", "Post-Workout",
        "Low Stress Day", "Hydration Goal Met", "Medication Adjusted",
        "Doctor Consultation", "Restorative Sleep",
    ]

    private static let titles: [String: LocalizedStringResource] = [
        "Day 14 Milestone": "Day 14 Milestone",
        "Consistent Routine": "Consistent Routine",
        "Morning Walk": "Morning Walk",
        "Post-Workout": "Post-Workout",
        "Low Stress Day": "Low Stress Day",
        "Hydration Goal Met": "Hydration Goal Met",
        "Medication Adjusted": "Medication Adjusted",
        "Doctor Consultation": "Doctor Consultation",
        "Restorative Sleep": "Restorative Sleep",
    ]

    static func title(for key: String) -> String {
        guard let resource = titles[key] else { return key }
        return String(localized: resource)
    }

    static func categoryTitle(for key: String?) -> String {
        guard let key else { return String(localized: "Diary photo") }
        return title(for: key)
    }
}
