//
//  BackgroundReader.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
import SwiftData

// MARK: - BackgroundReader

/// Long reads on its own ModelContext, off the main actor. Returns values only:
/// models never leave this actor.
@ModelActor
actor BackgroundReader {

    // MARK: - Dose History

    /// Keyed by start of day in `calendar`.
    func pills(onDays days: [Date], calendar: Calendar) throws -> [Date: [PillDose]] {
        let starts = days.map { calendar.startOfDay(for: $0) }
        guard let first = starts.min(), let last = starts.max() else { return [:] }
        let from = LocalDay(first, in: calendar).stored
        let end = LocalDay(last, in: calendar).adding(days: 1).stored

        let courses = try modelContext.fetch(FetchDescriptor<TreatmentCourse>())
        // Only the range's logs: `medication.logs` would fault in each medication's whole history.
        let logs = try modelContext.fetch(FetchDescriptor<DoseLog>(
            predicate: #Predicate { $0.storedSlot >= from && $0.storedSlot < end }
        ))
        let index = DoseDay.LogIndex(logs)

        var result: [Date: [PillDose]] = [:]
        for start in starts {
            result[start] = DoseDay.pills(of: courses, on: start, calendar: calendar, logs: index)
        }
        return result
    }

    // MARK: - Report

    func reportData(
        for selection: ReportSelection,
        profile: UserProfile,
        calendar: Calendar,
        now: Date
    ) throws -> ReportData {
        ReportAssembler(calendar: calendar, now: now).build(
            selection,
            profile: profile,
            courses: try modelContext.fetch(FetchDescriptor<TreatmentCourse>()),
            pressure: try modelContext.fetch(FetchDescriptor<BloodPressureReading>()),
            diary: try modelContext.fetch(FetchDescriptor<DiaryEntry>())
        )
    }
}
