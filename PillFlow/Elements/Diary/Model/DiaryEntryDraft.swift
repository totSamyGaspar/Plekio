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

    var emoji: String {
        switch self {
        case .great: return "⭐"
        case .good: return "😊"
        case .neutral: return "😐"
        case .downLow: return "😔"
        case .stressed: return "⚡"
        case .exhausted: return "😴"
        case .inPain: return "🩹"
        }
    }

    /// Mirrors the reference design's per-mood score — not a straight 1...7
    /// ramp; Stressed, Exhausted and Down/Low all score 2/5.
    var score: Int {
        switch self {
        case .great: return 5
        case .good: return 4
        case .neutral: return 3
        case .downLow: return 2
        case .stressed: return 2
        case .exhausted: return 2
        case .inPain: return 1
        }
    }
}

enum SleepQuality: String, CaseIterable, Identifiable {
    case poor = "P"
    case fair = "F"
    case good = "G"
    case excellent = "E"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}

/// Mutable, in-progress state for the Diary check-in form — mirrors how
/// MedicationDraft carries AddMedicationView's form state before
/// DatabaseService persists it.
struct DiaryEntryDraft: Identifiable, Equatable {
    var id = UUID()
    var checkInDate: Date = Date()
    var mood: DiaryMood = .good
    var physicalSummary: String = ""
    var energyLevel: Int = 4
    var discomfortLevel: Int = 0
    var sleepHours: Double = 7.5
    var sleepQuality: SleepQuality = .good
    var waterGlasses: Int = 6
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

enum DiarySymptomOptions {
    static let all = [
        "Headache", "Fatigue", "Brain Fog", "Mild Nausea", "Muscle Tension",
        "Joint Stiffness", "Dizziness", "Restlessness", "Digestive Discomfort",
        "Insomnia", "Dry Mouth", "Elevated Heartbeat",
    ]
}

enum DiaryMilestoneOptions {
    static let all = [
        "Day 14 Milestone", "Consistent Routine", "Morning Walk", "Post-Workout",
        "Low Stress Day", "Hydration Goal Met", "Medication Adjusted",
        "Doctor Consultation", "Restorative Sleep",
    ]
}
