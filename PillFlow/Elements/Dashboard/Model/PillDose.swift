//
//  PillDose.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation

enum DayPeriod: String, CaseIterable, Identifiable {
    case morning = "Morning"
    case noon = "Afternoon"
    case evening = "Evening"

    var id: String { self.rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .morning: return "Morning"
        case .noon:    return "Afternoon"
        case .evening: return "Evening"
        }
    }
}

struct PillDose: Identifiable, Equatable {
    
    var id: String { "\(medicationId.uuidString)@\(time.timeIntervalSince1970)" }

    let medicationId: UUID
    let name: String
    let dosage: Int
    let formSystemImage: String
    let time: Date
    let period: DayPeriod
    var isTaken: Bool
    // No image data here by design: the view loads the photo lazily via
    // ImageCache.shared.image(for:), keyed on medicationId,
    // instead of copying the photo blob into every PillDose instance.

    var stockCount: Int? = nil
    var lowStockThreshold: Int = 10
    
    var isMissed: Bool {
        return !isTaken && Date() > time.addingTimeInterval(3600)
    }

    var isLoggable: Bool {
        time <= Date() || Calendar.current.isDateInToday(time)
    }
}
