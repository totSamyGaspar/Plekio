//
//  TreatmentCourse.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

@Model
final class TreatmentCourse {
    @Attribute(.unique) var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date

    /// The course this one was created from by "Repeat", if any — the id of the
    /// FIRST course in the chain, not of the immediate parent, so every copy of
    /// the same treatment shares one value.
    ///
    /// It exists so a finished course can't be repeated while a copy of it is
    /// still running: matching on the name instead would break the moment the
    /// user renames one of them. Optional, so an existing store migrates to it
    /// without a version plan.
    var repeatedFromId: UUID?

    @Relationship(deleteRule: .cascade, inverse: \MedicationItem.course)
    var medications: [MedicationItem]
    
    init(name: String, startDate: Date, endDate: Date, repeatedFromId: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.repeatedFromId = repeatedFromId
        self.medications = []
    }

    /// Identifies the chain this course belongs to: the original itself, or the
    /// course every copy of it was made from.
    var repeatLineageId: UUID { repeatedFromId ?? id }
}
