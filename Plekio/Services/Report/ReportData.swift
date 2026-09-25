//
//  ReportData.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import Foundation

// MARK: - Report

/// The report as plain values: the renderer draws it and never sees a `@Model`.
nonisolated struct ReportData: Equatable {

    let profile: UserProfile
    let from: Date
    let to: Date
    let generatedAt: Date

    let courses: [CourseReport]
    let pressure: [PressureReading]
    let diary: [DiaryDay]

    var isEmpty: Bool { courses.isEmpty && pressure.isEmpty && diary.isEmpty }
}

// MARK: - Medications

nonisolated struct CourseReport: Equatable {

    let name: String
    let startDate: Date
    let endDate: Date
    let medications: [MedicationReport]

    var adherence: Adherence {
        medications.reduce(.none) { $0 + $1.adherence }
    }
}

nonisolated struct MedicationReport: Equatable {

    let name: String
    let dosage: Int
    let timesOfDay: [Date]
    let frequencyDays: Int
    let adherence: Adherence

    /// Only doses that were skipped or missed.
    let exceptions: [DoseException]
}

/// How doses went. The four counts partition the scheduled slots, so `scheduled` is derived.
nonisolated struct Adherence: Equatable {

    var taken = 0
    var skipped = 0
    var missed = 0

    /// Slots not yet due; excluded from `rate`.
    var upcoming = 0

    static let none = Adherence()

    var scheduled: Int { taken + skipped + missed + upcoming }

    /// Taken over settled slots; nil when nothing has come due (not the same as 0%).
    var rate: Double? {
        let settled = taken + skipped + missed
        guard settled > 0 else { return nil }
        return Double(taken) / Double(settled)
    }

    static func + (lhs: Adherence, rhs: Adherence) -> Adherence {
        Adherence(
            taken: lhs.taken + rhs.taken,
            skipped: lhs.skipped + rhs.skipped,
            missed: lhs.missed + rhs.missed,
            upcoming: lhs.upcoming + rhs.upcoming
        )
    }
}

nonisolated struct DoseException: Equatable {

    enum Kind: Equatable {
        /// Deliberately declined by the user.
        case skipped
        /// Never answered.
        case missed
    }

    let time: Date
    let kind: Kind
}

// MARK: - Blood Pressure

nonisolated struct PressureReading: Equatable {

    let measuredAt: Date
    let systolic: Int
    let diastolic: Int
    let pulse: Int?
}

// MARK: - Diary

nonisolated struct DiaryDay: Equatable {

    let date: Date
    let mood: String
    let moodScore: Int
    let energyLevel: Int
    let discomfortLevel: Int
    let sleepHours: Double
    let sleepQuality: String
    let waterGlasses: Int
    let symptoms: [String]
    let notes: String

    /// Empty unless the selection includes photos.
    let photoIds: [UUID]

    /// One-tap mood entry: sleep, water and energy are not measured and must not print as zero.
    let isQuickLog: Bool
}
