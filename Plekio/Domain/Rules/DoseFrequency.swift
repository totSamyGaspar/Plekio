//
//  DoseFrequency.swift
//  Plekio
//
//  Created by Edward Gasparian on 28.08.2026.
//

import Foundation

/// `nonisolated` because the PDF report, drawn off the main actor, uses the labels.
nonisolated enum DoseFrequency: Int, CaseIterable, Identifiable {

    // MARK: - Cases

    case daily = 1
    case everyOtherDay = 2
    case everyThreeDays = 3
    case weekly = 7
    case biweekly = 14
    case monthly = 30

    // MARK: - Properties

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

    // MARK: - Helpers

    /// Label for any interval, since stored data may not match a case.
    static func title(forDays days: Int) -> LocalizedStringResource {
        DoseFrequency(rawValue: days)?.title ?? "Every \(days) days"
    }
}
