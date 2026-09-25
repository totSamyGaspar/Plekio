//
//  CourseSnapshot.swift
//  Plekio
//
//  A course as the UI sees it: a value copied out of the store, not the live
//  SwiftData object.
//
//  Screens used to hold `TreatmentCourse` and `MedicationItem` directly. A
//  @Model is a reference into a live context: it changes under the screen when
//  something else writes, it can be deleted while a screen still shows it
//  (which is why `Route` already carries an id), it is not Sendable, and a test
//  that wants one has to build a real model object. A snapshot is none of that
//  — it is what was true when it was read, and a screen reads again after it
//  writes.
//
//  Writes go back by id, through CourseRepository.
//

import Foundation

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

nonisolated struct CourseSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let startDate: Date
    let endDate: Date
    let repeatedFromId: UUID?

    /// Sorted by name: SwiftData does not define an order for a to-many
    /// relationship, so an unsorted list can come back shuffled between launches.
    let medications: [MedicationSnapshot]

    /// The chain this course belongs to — see `TreatmentCourse.repeatLineageId`.
    var repeatLineageId: UUID { repeatedFromId ?? id }

    /// Same rule as `TreatmentCourse.isActive` — both read `CourseRules`.
    func isActive(on day: Date = Date(), calendar: Calendar = .current) -> Bool {
        CourseRules.isActive(endDate: endDate, on: day, calendar: calendar)
    }

    /// Whether this treatment is already running again — the course itself or
    /// any copy of it is among `activeCourses`. Matched on the repeat lineage,
    /// not on the name, so a renamed copy still counts.
    func hasActiveRepeat(among activeCourses: [CourseSnapshot]) -> Bool {
        let lineage = repeatLineageId
        return activeCourses.contains { $0.repeatLineageId == lineage }
    }
}

// MARK: - Mapping from the store
//
// The one place a model becomes a snapshot. On the main actor because that is
// where the models live.

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
