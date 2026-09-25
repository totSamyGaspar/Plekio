//
//  DoseHistoryReader.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
import SwiftData

// MARK: - DoseHistoryReader

/// Reads many days of doses on its own ModelContext, off the main actor.
/// Returns values only: models never leave this actor.
@ModelActor
actor DoseHistoryReader {

    /// Keyed by start of day in `calendar`.
    func pills(onDays days: [Date], calendar: Calendar) throws -> [Date: [PillDose]] {
        let courses = try modelContext.fetch(FetchDescriptor<TreatmentCourse>())

        var result: [Date: [PillDose]] = [:]
        for day in days {
            let start = calendar.startOfDay(for: day)
            result[start] = DoseDay.pills(of: courses, on: start, calendar: calendar)
        }
        return result
    }
}
