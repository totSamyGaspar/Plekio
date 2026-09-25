//
//  TreatmentCourse.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

/// `nonisolated`: DoseHistoryReader reads it on a background context.
@Model
nonisolated final class TreatmentCourse {

    // MARK: - Properties

    @Attribute(.unique) var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date

    /// Id of the FIRST course in the "Repeat" chain (not the parent), nil for originals.
    /// Optional so existing stores migrate without a version plan.
    var repeatedFromId: UUID?

    @Relationship(deleteRule: .cascade, inverse: \MedicationItem.course)
    var medications: [MedicationItem]

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
