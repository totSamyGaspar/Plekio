//
//  WidgetSnapshot.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

/// Everything the widget shows, written by the app as JSON beside the store.
/// Its own types, not PillDose or MedicationForm: the widget builds only Shared,
/// and the file must stay readable when the app's models change.
/// Its nested types are each in their own WidgetSnapshot<Type>.swift.
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

    // Optional, so a snapshot an older build wrote still reads.

    /// The diary check-in of the day the snapshot was built; nil if there is none.
    var diary: DiaryDay? = nil

    /// The latest blood-pressure readings, oldest first, at most seven.
    var bloodPressure: [Reading]? = nil

    // MARK: - Empty

    /// No courses yet, or the data was erased.
    static func empty(at date: Date, missedGrace: TimeInterval) -> WidgetSnapshot {
        WidgetSnapshot(generatedAt: date, missedGrace: missedGrace, slots: [], streakDays: 0, lowStock: [])
    }
}
