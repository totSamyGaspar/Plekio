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
        var startDate: Date = Date.distantPast
        var endDate: Date = Date.distantPast

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

        // MARK: - Init

        init(name: String, startDate: Date, endDate: Date, repeatedFromId: UUID? = nil) {
            self.id = UUID()
            self.name = name
            self.startDate = startDate
            self.endDate = endDate
            self.repeatedFromId = repeatedFromId
            self.medications = []
        }

        // MARK: - Lineage

        /// The chain this course belongs to: the original course's id.
        var repeatLineageId: UUID { repeatedFromId ?? id }
    }
}
