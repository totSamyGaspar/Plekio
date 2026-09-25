//
//  ReportData.swift
//  Plekio
//

import Foundation

/// The document, as values.
///
/// The seam between the two halves of the export: the builder reads SwiftData
/// and produces this, the renderer draws it and never sees a `@Model`. That is
/// what lets page layout be tested without a store, and the numbers be tested
/// without a PDF.
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

    /// Only the doses that did not go as planned. A full log of a year is
    /// thousands of identical lines, and what a reader looks for in it is the
    /// handful that are not.
    let exceptions: [DoseException]
}

/// How a course of doses actually went.
///
/// The four counts partition every slot the schedule called for, so they always
/// add up to `scheduled` — which is why `scheduled` is derived rather than
/// stored beside them and free to drift.
nonisolated struct Adherence: Equatable {

    var taken = 0
    var skipped = 0
    var missed = 0

    /// Slots inside the period that have not come due yet. Counted separately
    /// so a course still running is not marked down for tomorrow.
    var upcoming = 0

    static let none = Adherence()

    var scheduled: Int { taken + skipped + missed + upcoming }

    /// Nil when nothing has come due — no adherence at all, which is not the
    /// same as nothing taken.
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
        /// The user said no on purpose.
        case skipped
        /// Nobody ever answered.
        case missed
    }

    let time: Date
    let kind: Kind
}

// MARK: - Blood pressure

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

    /// Empty unless the selection asked for photos — the builder drops them
    /// rather than the renderer deciding twice.
    let photoIds: [UUID]

    /// A one-tap mood entry has no sleep, water or energy behind it; printing
    /// zeroes for those would read as measurements.
    let isQuickLog: Bool
}
