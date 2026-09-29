//
//  ScheduleRevision.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
import SwiftData

// MARK: - ScheduleRevision

nonisolated extension SchemaV1 {

    /// A medication's schedule as it was before a change. Applies to days before
    /// `validUntil`; the medication's own fields apply from then on. Keeps past
    /// days, statistics and the report on the schedule that was actually in force.
    /// `nonisolated`: BackgroundReader reads it on a background context.
    @Model
    nonisolated final class ScheduleRevision {

        // MARK: - Properties

        /// Start of the first day this schedule no longer applies to (exclusive end).
        var validUntil: Date
        var timesOfDay: [Date]
        var frequencyDays: Int
        var dosage: Int

        var medication: MedicationItem?

        // MARK: - Init

        init(validUntil: Date, timesOfDay: [Date], frequencyDays: Int, dosage: Int) {
            self.validUntil = validUntil
            self.timesOfDay = timesOfDay
            self.frequencyDays = frequencyDays
            self.dosage = dosage
        }
    }
}
