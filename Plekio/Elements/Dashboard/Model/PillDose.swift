//
//  PillDose.swift
//  Plekio
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
    /// What the user has answered for this slot — the same DoseStatus the log
    /// stores. It used to be two independent flags, `isTaken` and `isSkipped`,
    /// that nothing kept from being true together; each writer (the database
    /// read, the test mocks, the previews) had to remember to clear one when it
    /// set the other.
    var status: DoseStatus = .pending
    // No image data here by design: the view loads the photo lazily via
    // the environment's imageLoader, keyed on medicationId,
    // instead of copying the photo blob into every PillDose instance.
    
    var stockCount: Int? = nil
    var lowStockThreshold: Int = 10
    
    /// Late and unaccounted for. A skipped dose is accounted for — the user
    /// answered — so it never becomes "missed" no matter how long ago it was.
    var isTaken: Bool { status.isTaken }
    var isSkipped: Bool { status.isSkipped }

    var isMissed: Bool {
        isMissed(at: Date())
    }

    /// Late and unaccounted for, as of `now`. The rule itself — the property
    /// above is the view's "as of this render".
    func isMissed(at now: Date) -> Bool {
        status == .pending && now > time.addingTimeInterval(DoseSchedule.missedGrace)
    }
    
    var isLoggable: Bool {
        isLoggable(at: Date())
    }

    /// Past, or later today — a future day cannot be logged in advance.
    func isLoggable(at now: Date, calendar: Calendar = .current) -> Bool {
        time <= now || calendar.isDate(time, inSameDayAs: now)
    }
}
