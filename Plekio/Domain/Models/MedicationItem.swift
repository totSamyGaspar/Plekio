//
//  MedicationItem.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

nonisolated extension SchemaV2 {

    /// `nonisolated`: BackgroundReader reads it on a background context.
    @Model
    nonisolated final class MedicationItem {

        // MARK: - Properties

        // No image property on purpose: photos live on disk keyed by `id`.
        var id: UUID = UUID()
        var name: String = ""
        /// A `MedicationForm` raw value; read through `form`.
        var formRaw: String = "pill"
        var dosage: Int = 1
        /// Wall-clock dose times, see `MinuteOfDay`.
        var minutesOfDay: [Int] = []
        var frequencyDays: Int = 1
        var course: TreatmentCourse?
        /// First day it's taken, when added to a course already running; nil means from the course start.
        @Attribute(originalName: "startDate") var storedStartDay: Date?
        var stockCount: Int = 0
        var lowStockThreshold: Int = 0
        /// A `MealTiming` raw value, nil when it doesn't matter; read through `mealTiming`.
        var mealTimingRaw: String?

        // Optional, as CloudKit requires of every relationship; read through `logs`.
        @Relationship(deleteRule: .cascade, originalName: "logs", inverse: \SchemaV2.DoseLog.medication)
        var storedLogs: [DoseLog]? = []

        /// Earlier schedules, so a change doesn't rewrite past days.
        @Relationship(deleteRule: .cascade, originalName: "scheduleRevisions", inverse: \SchemaV2.ScheduleRevision.medication)
        var storedScheduleRevisions: [ScheduleRevision]? = []

        var logs: [DoseLog] {
            get { storedLogs ?? [] }
            set { storedLogs = newValue }
        }

        var scheduleRevisions: [ScheduleRevision] {
            get { storedScheduleRevisions ?? [] }
            set { storedScheduleRevisions = newValue }
        }

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
            startDate: Date? = nil,
            mealTiming: MealTiming? = nil
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
            self.mealTimingRaw = mealTiming?.rawValue
        }

        /// An unknown raw value (from a newer version) reads as a pill instead of failing.
        var form: MedicationForm {
            get { MedicationForm(rawValue: formRaw) ?? .pill }
            set { formRaw = newValue.rawValue }
        }

        /// First day it's taken, when added to a course already running; nil means from the course start.
        var startDay: LocalDay? {
            get { storedStartDay.map(LocalDay.init(stored:)) }
            set { storedStartDay = newValue?.stored }
        }

        /// That day's midnight where the person is now; rules use `startDay`.
        var startDate: Date? {
            get { startDay?.start(in: .autoupdatingCurrent) }
            set { startDay = newValue.map { LocalDay($0, in: .autoupdatingCurrent) } }
        }

        /// An unknown raw value (from a newer version) reads as "doesn't matter".
        var mealTiming: MealTiming? {
            get { mealTimingRaw.flatMap(MealTiming.init(rawValue:)) }
            set { mealTimingRaw = newValue?.rawValue }
        }
    }
}
