//
//  PillDose.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation

// MARK: - DayPeriod

nonisolated enum DayPeriod: String, CaseIterable, Identifiable, Sendable {
    case morning = "Morning"
    case noon = "Afternoon"
    case evening = "Evening"

    var id: String { self.rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .morning: return "Morning"
        case .noon:    return "Afternoon"
        case .evening: return "Evening"
        }
    }
}

// MARK: - PillDose

nonisolated struct PillDose: Identifiable, Equatable, Sendable {

    var id: String { "\(medicationId.uuidString)@\(time.timeIntervalSince1970)" }

    let medicationId: UUID
    let name: String
    let dosage: Int
    let formSystemImage: String
    let time: Date
    let period: DayPeriod
    var status: DoseStatus = .pending
    // No image data: the view loads the photo lazily by medicationId.

    var stockCount: Int? = nil
    var lowStockThreshold: Int = 10
    /// For "Open course"; nil in previews.
    var courseId: UUID? = nil

    // MARK: - Status

    var isTaken: Bool { status.isTaken }
    var isSkipped: Bool { status.isSkipped }

    /// Pending past the grace period. A skipped dose is never missed.
    var isMissed: Bool {
        isMissed(at: Date())
    }

    /// Pending past `DoseSchedule.missedGrace`; skipped never counts as missed.
    func isMissed(at now: Date) -> Bool {
        status == .pending && now > time.addingTimeInterval(DoseSchedule.missedGrace)
    }

    var isLoggable: Bool {
        isLoggable(at: Date())
    }

    /// Past, or later today; future days cannot be logged in advance.
    func isLoggable(at now: Date, calendar: Calendar = .current) -> Bool {
        time <= now || calendar.isDate(time, inSameDayAs: now)
    }
}
