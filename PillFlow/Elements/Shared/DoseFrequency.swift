//
//  DoseFrequency.swift
//  PillFlow
//
//  Dose intervals in a single list.
//
//  The labels used to live in two places: the Picker items in
//  AddMedicationView and a switch over the day count in MedicationRowView —
//  two sources of truth for the same set of values.
//

import Foundation

enum DoseFrequency: Int, CaseIterable, Identifiable {
    case daily = 1
    case everyOtherDay = 2
    case everyThreeDays = 3
    case weekly = 7
    case biweekly = 14
    case monthly = 30

    var id: Int { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .daily:          return "Every day"
        case .everyOtherDay:  return "Every other day"
        case .everyThreeDays: return "Every 3 days"
        case .weekly:         return "Once a week"
        case .biweekly:       return "Every 2 weeks"
        case .monthly:        return "Once a month"
        }
    }

    /// Label for an arbitrary interval: the data may not come from this list
    /// (migration, import).
    static func title(forDays days: Int) -> LocalizedStringResource {
        DoseFrequency(rawValue: days)?.title ?? "Every \(days) days"
    }
}
