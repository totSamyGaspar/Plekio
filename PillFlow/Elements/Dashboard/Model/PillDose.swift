//
//  PillDose.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation

// Day periods for the sections on the main screen
enum DayPeriod: String, CaseIterable, Identifiable {
    case morning = "Morning"
    case noon = "Afternoon"
    case evening = "Evening"
    var id: String { self.rawValue }
}

// Model of a single pill dose
struct PillDose: Identifiable {
    let id = UUID()
    let medicationId: UUID
    let name: String
    let dosage: String
    let formSystemImage: String
    let time: Date
    let period: DayPeriod
    var isTaken: Bool
    // No image data here by design: the view loads the photo lazily via
    // ImageCache.shared.loadAsync(for:completion:), keyed on medicationId,
    // instead of copying the photo blob into every PillDose instance.

    var stockCount: Int? = 9
    var lowStockThreshold: Int = 10
    
    var isMissed: Bool {
        return !isTaken && Date() > time.addingTimeInterval(3600)
    }
}
