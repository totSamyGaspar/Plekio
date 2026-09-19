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
    /// Deliberately passed on, as opposed to merely not logged yet. Declared
    /// after isTaken and before the stock fields so the memberwise initialiser
    /// keeps its existing argument order.
    var isSkipped: Bool = false
    // No image data here by design: the view loads the photo lazily via
    // ImageCache.shared.image(for:), keyed on medicationId,
    // instead of copying the photo blob into every PillDose instance.
    
    var stockCount: Int? = nil
    var lowStockThreshold: Int = 10
    
    /// Late and unaccounted for. A skipped dose is accounted for — the user
    /// answered — so it never becomes "missed" no matter how long ago it was.
    var isMissed: Bool {
        return !isTaken && !isSkipped && Date() > time.addingTimeInterval(DoseSchedule.missedGrace)
    }
    
    var isLoggable: Bool {
        time <= Date() || Calendar.current.isDateInToday(time)
    }
}
