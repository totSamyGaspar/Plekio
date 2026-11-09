//
//  TreatmentCourse.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

nonisolated extension SchemaV2 {

    /// `nonisolated`: BackgroundReader reads it on a background context.
    @Model
    nonisolated final class TreatmentCourse {

        // MARK: - Properties

        var id: UUID = UUID()
        var name: String = ""
        /// The first and last days as `LocalDay.stored`; read through `startDay` and `endDay`.
        @Attribute(originalName: "startDate") var storedStartDay: Date = Date.distantPast
        @Attribute(originalName: "endDate") var storedEndDay: Date = Date.distantPast

        /// Id of the FIRST course in the "Repeat" chain (not the parent), nil for originals.
        var repeatedFromId: UUID?

        // Optional, as CloudKit requires of every relationship; read through `medications`.
        @Relationship(deleteRule: .cascade, originalName: "medications", inverse: \SchemaV2.MedicationItem.course)
        var storedMedications: [MedicationItem]? = []

        @Relationship(deleteRule: .cascade, originalName: "dateRevisions", inverse: \SchemaV2.CourseDateRevision.course)
        var storedDateRevisions: [CourseDateRevision]? = []

        var medications: [MedicationItem] {
            get { storedMedications ?? [] }
            set { storedMedications = newValue }
        }

        var dateRevisions: [CourseDateRevision] {
            get { storedDateRevisions ?? [] }
            set { storedDateRevisions = newValue }
        }

        var startDay: LocalDay {
            get { LocalDay(stored: storedStartDay) }
            set { storedStartDay = newValue.stored }
        }

        var endDay: LocalDay {
            get { LocalDay(stored: storedEndDay) }
            set { storedEndDay = newValue.stored }
        }

        /// The days' midnights where the person is now: for screens, pickers and sorting.
        /// Rules work on `startDay` and `endDay`.
        var startDate: Date {
            get { startDay.start(in: .autoupdatingCurrent) }
            set { startDay = LocalDay(newValue, in: .autoupdatingCurrent) }
        }

        var endDate: Date {
            get { endDay.start(in: .autoupdatingCurrent) }
            set { endDay = LocalDay(newValue, in: .autoupdatingCurrent) }
        }

        // MARK: - Init

        init(name: String, startDate: Date, endDate: Date, repeatedFromId: UUID? = nil) {
            self.id = UUID()
            self.name = name
            self.startDate = startDate
            self.endDate = endDate
            self.repeatedFromId = repeatedFromId
            self.medications = []
        }

        init(name: String, startDay: LocalDay, endDay: LocalDay, repeatedFromId: UUID? = nil) {
            self.id = UUID()
            self.name = name
            self.startDay = startDay
            self.endDay = endDay
            self.repeatedFromId = repeatedFromId
            self.medications = []
        }

        // MARK: - Lineage

        /// The chain this course belongs to: the original course's id.
        var repeatLineageId: UUID { repeatedFromId ?? id }
    }
}
