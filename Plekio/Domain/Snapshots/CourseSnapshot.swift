//
//  CourseSnapshot.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - MedicationSnapshot

nonisolated struct MedicationSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let formSystemImage: String
    let dosage: Int
    let timesOfDay: [Date]
    let frequencyDays: Int
    let stockCount: Int
    let lowStockThreshold: Int

    var isLowOnStock: Bool { stockCount <= lowStockThreshold }
}

// MARK: - CourseSnapshot

/// Immutable read of a course; writes go back by id through CourseRepository.
nonisolated struct CourseSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let startDate: Date
    let endDate: Date
    let repeatedFromId: UUID?

    /// Sorted by name: SwiftData to-many relationships have no stable order.
    let medications: [MedicationSnapshot]

    /// See `TreatmentCourse.repeatLineageId`.
    var repeatLineageId: UUID { repeatedFromId ?? id }

    /// Shares `CourseRules` with `TreatmentCourse.isActive`.
    func isActive(on day: Date, calendar: Calendar) -> Bool {
        CourseRules.isActive(endDate: endDate, on: day, calendar: calendar)
    }

    /// True when this course or a copy is active. Matched by lineage, not name,
    /// so a renamed copy still counts.
    func hasActiveRepeat(among activeCourses: [CourseSnapshot]) -> Bool {
        let lineage = repeatLineageId
        return activeCourses.contains { $0.repeatLineageId == lineage }
    }
}

// MARK: - Mapping from the store

// Main actor: SwiftData models live there.

@MainActor
extension MedicationSnapshot {
    init(_ model: MedicationItem) {
        self.init(
            id: model.id,
            name: model.name,
            formSystemImage: model.formSystemImage,
            dosage: model.dosage,
            timesOfDay: model.timesOfDay,
            frequencyDays: model.frequencyDays,
            stockCount: model.stockCount,
            lowStockThreshold: model.lowStockThreshold
        )
    }
}

@MainActor
extension CourseSnapshot {
    init(_ model: TreatmentCourse) {
        self.init(
            id: model.id,
            name: model.name,
            startDate: model.startDate,
            endDate: model.endDate,
            repeatedFromId: model.repeatedFromId,
            medications: model.medications
                .map { MedicationSnapshot($0) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        )
    }
}
