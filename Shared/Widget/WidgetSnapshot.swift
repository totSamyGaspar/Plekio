//
//  WidgetSnapshot.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

// MARK: - WidgetSnapshot

/// Everything the widget shows, written by the app as JSON beside the store.
/// Its own types, not PillDose or MedicationForm: the widget builds only Shared,
/// and the file must stay readable when the app's models change.
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {

    /// Bumped on a change the old widget can't read; an unknown version reads as nothing.
    static let currentVersion = 1

    var version = WidgetSnapshot.currentVersion

    /// When the app built it; the streak and stock are as of this moment.
    var generatedAt: Date

    /// `DoseSchedule.missedGrace`, carried so the widget marks missed doses at the same moment as Today.
    var missedGrace: TimeInterval

    /// Today's and tomorrow's slots, in time order. Tomorrow lets the widget roll
    /// over at midnight without the app running.
    var slots: [Slot]

    var streakDays: Int

    /// Medications of active courses at or below their threshold, lowest stock first.
    var lowStock: [StockAlert]

    // MARK: - Slot

    /// The doses due at one time of day, like one "Up next" card.
    struct Slot: Codable, Equatable, Sendable, Identifiable {
        var time: Date
        var period: Period
        var doses: [Dose]

        var id: Date { time }
    }

    enum Period: String, Codable, Sendable {
        case morning, afternoon, evening
    }

    // MARK: - Dose

    struct Dose: Codable, Equatable, Sendable, Identifiable {
        var medicationId: UUID
        var name: String
        var dosage: Int
        var form: Form
        var status: Status

        /// Unique within a slot: a medication has one dose per slot.
        var id: UUID { medicationId }
    }

    /// Mirrors `MedicationForm`'s stored raw values.
    enum Form: String, Codable, Sendable {
        case pill, capsule, drops, injection

        /// A form a newer app added reads as a pill instead of failing the whole snapshot.
        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Form(rawValue: raw) ?? .pill
        }

        var systemImage: String {
            switch self {
            case .pill: "pills.fill"
            case .capsule: "capsule.fill"
            case .drops: "drop.fill"
            case .injection: "syringe.fill"
            }
        }
    }

    /// Missed is not stored: it depends on the time the widget is drawn at.
    enum Status: String, Codable, Sendable {
        case pending, taken, skipped

        var isSettled: Bool { self != .pending }
    }

    // MARK: - StockAlert

    struct StockAlert: Codable, Equatable, Sendable, Identifiable {
        var medicationId: UUID
        var name: String
        var stock: Int
        var threshold: Int

        var id: UUID { medicationId }
    }

    // MARK: - Empty

    /// No courses yet, or the data was erased.
    static func empty(at date: Date, missedGrace: TimeInterval) -> WidgetSnapshot {
        WidgetSnapshot(generatedAt: date, missedGrace: missedGrace, slots: [], streakDays: 0, lowStock: [])
    }
}
