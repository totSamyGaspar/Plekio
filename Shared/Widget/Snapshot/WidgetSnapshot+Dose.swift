//
//  WidgetSnapshot+Dose.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

// MARK: - Dose

extension WidgetSnapshot {

    nonisolated struct Dose: Codable, Equatable, Sendable, Identifiable {
        var medicationId: UUID
        var name: String
        var dosage: Int
        var form: Form
        var status: Status

        /// Unique within a slot: a medication has one dose per slot.
        var id: UUID { medicationId }
    }
}
