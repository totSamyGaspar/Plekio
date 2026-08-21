//
//  MedicationDraft.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct MedicationDraft: Identifiable, Equatable {
    var id = UUID()
    var name: String = ""
    var formSystemImage: String = "pills.fill"
    var dosage: Int = 1
    var timesOfDay: [Date] = [Date()]
    var frequencyDays: Int = 1
    var medicationImageData: Data? = nil
    
    var stockCount: Int = 30
    var lowStockThreshold: Int = 10
}
