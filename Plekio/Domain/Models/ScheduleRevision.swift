//
//  ScheduleRevision.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
import SwiftData

// MARK: - ScheduleRevision

nonisolated extension SchemaV2 {

    /// A medication's schedule as it was before a change. Applies to days before
    /// `validUntil`; the medication's own fields apply from then on. Keeps past
    /// days, statistics and the report on the schedule that was actually in force.
    /// `nonisolated`: BackgroundReader reads it on a background context.
    @Model
    nonisolated final class ScheduleRevision {

        // MARK: - Properties

        /// The first day this schedule no longer applies to (exclusive end), as
        /// `LocalDay.stored`; read through `validUntilDay`.
        @Attribute(originalName: "validUntil") var storedValidUntil: Date = Date.distantPast
        var minutesOfDay: [Int] = []
        var frequencyDays: Int = 1
        var dosage: Int = 1

        var medication: MedicationItem?

        // MARK: - Init

        init(validUntil: Date, minutesOfDay: [Int], frequencyDays: Int, dosage: Int) {
            self.validUntil = validUntil
            self.minutesOfDay = minutesOfDay
            self.frequencyDays = frequencyDays
            self.dosage = dosage
        }

        init(validUntilDay: LocalDay, minutesOfDay: [Int], frequencyDays: Int, dosage: Int) {
            self.validUntilDay = validUntilDay
            self.minutesOfDay = minutesOfDay
            self.frequencyDays = frequencyDays
            self.dosage = dosage
        }

        var validUntilDay: LocalDay {
            get { LocalDay(stored: storedValidUntil) }
            set { storedValidUntil = newValue.stored }
        }

        /// That day's midnight where the person is now; rules use `validUntilDay`.
        var validUntil: Date {
            get { validUntilDay.start(in: .autoupdatingCurrent) }
            set { validUntilDay = LocalDay(newValue, in: .autoupdatingCurrent) }
        }
    }
}
