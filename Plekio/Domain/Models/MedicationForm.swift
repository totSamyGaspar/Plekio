//
//  MedicationForm.swift
//  Plekio
//
//  Created by Edward Gasparian on 29.09.2026.
//

import Foundation

/// What the medication is. The store keeps `rawValue`, never the icon, so icons
/// can change freely. Raw values are stored: never rename them.
nonisolated enum MedicationForm: String, CaseIterable, Sendable {
    case pill, capsule, drops, injection

    var systemImage: String {
        switch self {
        case .pill: "pills.fill"
        case .capsule: "capsule.fill"
        case .drops: "drop.fill"
        case .injection: "syringe.fill"
        }
    }
}
