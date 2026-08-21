//
//  PillDose.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation

// Периоды дня для секций на главном экране
enum DayPeriod: String, CaseIterable, Identifiable {
    case morning = "Morning"
    case noon = "Afternoon"
    case evening = "Evening"
    var id: String { self.rawValue }
}

// Модель конкретного приема таблетки
struct PillDose: Identifiable {
    let id = UUID()
    let medicationId: UUID
    let name: String
    let dosage: String
    let formSystemImage: String
    let time: Date
    let period: DayPeriod
    var isTaken: Bool
    var medicationImageData: Data?
    
    var stockCount: Int? = 9
    var lowStockThreshold: Int = 10
    
    var isMissed: Bool {
        return !isTaken && Date() > time.addingTimeInterval(3600)
    }
}
