//
//  Route.swift
//  PillFlow
//
//  Created by Edward Gasparian on 14.06.2026.
//

import Foundation

enum Route: Hashable {
    case courseDetail(TreatmentCourse)

    // Add more cases here as the app grows, e.g.:
    // case medicationDetail(MedicationItem)
    // case statistics
}

enum SheetRoute: Identifiable {
    
    case newTreatment
    case addMedication(onSave: (MedicationDraft) -> Void)
    case takePill(pills: [PillDose], onTake: () -> Void, onSkip: () -> Void)
    
    // Identifiable is required for .sheet(item:).
    var id: String {
        switch self {
        case .newTreatment:       return "newTreatment"
        case .addMedication:      return "addMedication"
        case .takePill(let pills, _, _):
            return "takePill-\(pills.map { $0.id.uuidString }.joined(separator: "-"))"
        }
    }
}
