//
//  DiaryEntryDraft.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//

import Foundation

enum DiaryMood: String, CaseIterable, Identifiable {
    case great = "Great"
    case good = "Good"
    case neutral = "Neutral"
    case downLow = "Down / Low"
    case stressed = "Stressed"
    case exhausted = "Exhausted"
    case inPain = "In Pain"
    
    var id: String { rawValue }
    
    /// Display label for the mood. `rawValue` is the stored key
    /// (`DiaryEntry.moodLabel`) and has to stay an unchanging English string —
    /// translating it would orphan every entry already saved.
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
    
    /// Mirrors the reference design's per-mood score — not a straight 1...7
    /// ramp; Stressed, Exhausted and Down/Low all score 2/5.
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

enum SleepQuality: String, CaseIterable, Identifiable {
    case poor = "P"
    case fair = "F"
    case good = "G"
    case excellent = "E"
    
    var id: String { rawValue }
    
    /// Single-letter label for the compact buttons. `rawValue` won't do here:
    /// P/F/G/E are storage keys and mean nothing in other languages.
    var initial: LocalizedStringResource {
        switch self {
        case .poor:      return "P"
        case .fair:      return "F"
        case .good:      return "G"
        case .excellent: return "E"
        }
    }
    
    /// As with DiaryMood, `rawValue` is the storage key and this is the UI label.
    var title: LocalizedStringResource {
        switch self {
        case .poor:      return "Poor"
        case .fair:      return "Fair"
        case .good:      return "Good"
        case .excellent: return "Excellent"
        }
    }
}

/// Mutable, in-progress state for the Diary check-in form — mirrors how
/// MedicationDraft carries AddMedicationView's form state before
/// DatabaseService persists it.
struct DiaryEntryDraft: Identifiable, Equatable {
    
    /// The ranges the numeric fields are held to.
    ///
    /// Enforced here rather than in whichever control happens to edit a field.
    /// The sleep field clamped itself, the water stepper guarded only its minus
    /// button — its plus button had no ceiling at all — and `init(from:)`, which
    /// loads an entry back out of storage, checked nothing. A bound that lives
    /// in one of three writers is a bound that holds two thirds of the time.
    static let energyLevelRange = 1...5
    static let discomfortLevelRange = 0...10
    static let sleepHoursRange = 0.0...24.0
    static let waterGlassesRange = 0...50
    
    var id = UUID()
    var checkInDate: Date = Date()
    var mood: DiaryMood = .good
    var physicalSummary: String = ""
    
    // didSet does not run during initialization, which is why init(from:) below
    // clamps its arguments as well. Assigning inside didSet does not re-enter it.
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
    // Compressed (JPEG) photo bytes — written to disk via ImageCache only on save,
    // same lazy-write approach as MedicationDraft.medicationImageData.
    var photos: [Data] = []
    // Set by DiaryViewModel.quickLog(mood:) for entries created via the home
    // screen's one-tap mood chips — see DiaryEntry.isQuickLog for why this
    // matters to stats and display.
    var isQuickLog: Bool = false
    // Tracks whether the user actually added/removed a photo this session —
    // set by DiaryCheckInViewModel.requestImageSelection/removePhoto, NOT by
    // DiaryCheckInView.init(editingEntry:) preloading the existing photos.
    // DatabaseService.updateDiaryEntry uses this to skip deleting/rewriting
    // photo files on disk when the user didn't touch photos at all — without
    // it, every edit-and-save (even one that only changes, say, mood)
    // deleted and rewrote every photo file under fresh UUIDs for nothing.
    var photosModified: Bool = false
}

extension DiaryEntryDraft {
    
    /// The energy scale in words.
    ///
    /// "Four out of five is High Energy" is this app's vocabulary, not a layout
    /// decision, so it is defined with the value rather than in the card that
    /// happens to draw it.
    var energyDescription: LocalizedStringResource {
        switch energyLevel {
        case ..<2: return "Low Energy"
        case 2...3: return "Moderate Energy"
        default: return "High Energy"
        }
    }
    
    /// The discomfort scale in words.
    var discomfortDescription: LocalizedStringResource {
        switch discomfortLevel {
        case 0:     return "Zero Pain"
        case 1...3: return "Mild"
        case 4...6: return "Manageable"
        default:    return "Severe"
        }
    }
    
    init(from entry: DiaryEntry) {
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
