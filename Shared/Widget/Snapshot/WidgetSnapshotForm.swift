//
//  WidgetSnapshotForm.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

extension WidgetSnapshot {

    /// Mirrors `MedicationForm`'s stored raw values.
    nonisolated enum Form: String, Codable, Sendable {
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
}
