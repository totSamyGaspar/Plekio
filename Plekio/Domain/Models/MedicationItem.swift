//
//  MedicationItem.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

nonisolated extension SchemaV1 {

    /// `nonisolated`: BackgroundReader reads it on a background context.
    @Model
    nonisolated final class MedicationItem {

        // MARK: - Properties

        // No image property on purpose: photos live on disk keyed by `id`.
        @Attribute(.unique) var id: UUID
        var name: String
        /// A `MedicationForm` raw value; read through `form`.
        var formRaw: String
        var dosage: Int
        /// Wall-clock dose times, see `MinuteOfDay`.
        var minutesOfDay: [Int]
        var frequencyDays: Int
        var course: TreatmentCourse?
        /// First day it's taken, when added to a course already running; nil means from the course start.
        var startDate: Date?
        var stockCount: Int
        var lowStockThreshold: Int

        @Relationship(deleteRule: .cascade, inverse: \SchemaV1.DoseLog.medication)
        var logs: [DoseLog]

        /// Earlier schedules, so a change doesn't rewrite past days.
        @Relationship(deleteRule: .cascade, inverse: \SchemaV1.ScheduleRevision.medication)
        var scheduleRevisions: [ScheduleRevision]

        // MARK: - Init

        init(
            id: UUID,
            name: String,
            form: MedicationForm,
            dosage: Int,
            minutesOfDay: [Int],
            frequencyDays: Int,
            stockCount: Int = 30,
            lowStockThreshold: Int = 10,
            startDate: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.formRaw = form.rawValue
            self.dosage = dosage
            self.minutesOfDay = minutesOfDay
            self.frequencyDays = frequencyDays
            self.logs = []
            self.scheduleRevisions = []
            self.stockCount = stockCount
            self.lowStockThreshold = lowStockThreshold
            self.startDate = startDate
        }

        /// An unknown raw value (from a newer version) reads as a pill instead of failing.
        var form: MedicationForm {
            get { MedicationForm(rawValue: formRaw) ?? .pill }
            set { formRaw = newValue.rawValue }
        }
    }
}
