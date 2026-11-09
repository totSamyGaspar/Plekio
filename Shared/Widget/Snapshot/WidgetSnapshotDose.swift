//
//  WidgetSnapshotDose.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

extension WidgetSnapshot {

    nonisolated struct Dose: Codable, Equatable, Sendable, Identifiable {
        var medicationId: UUID
        var name: String
        var dosage: Int
        var form: Form
        var status: Status
        /// `MealTiming`'s raw value; the widget words it in its own language, which can
        /// differ from the app's. Optional, so snapshots written before it still decode.
        var mealTiming: String? = nil

        /// Unique within a slot: a medication has one dose per slot.
        var id: UUID { medicationId }
    }
}
