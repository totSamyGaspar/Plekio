//
//  MedicationItem.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

/// `nonisolated`: BackgroundReader reads it on a background context.
@Model
nonisolated final class MedicationItem {

    // MARK: - Properties

    // No image property on purpose: photos live on disk keyed by `id`.
    @Attribute(.unique) var id: UUID
    var name: String
    var formSystemImage: String
    var dosage: Int
    var timesOfDay: [Date]
    var frequencyDays: Int
    var course: TreatmentCourse?
    var stockCount: Int
    var lowStockThreshold: Int

    @Relationship(deleteRule: .cascade, inverse: \DoseLog.medication)
    var logs: [DoseLog]

    // MARK: - Init

    init(
        id: UUID,
        name: String,
        formSystemImage: String,
        dosage: Int,
        timesOfDay: [Date],
        frequencyDays: Int,
        stockCount: Int = 30,
        lowStockThreshold: Int = 10
    ) {
        self.id = id
        self.name = name
        self.formSystemImage = formSystemImage
        self.dosage = dosage
        self.timesOfDay = timesOfDay
        self.frequencyDays = frequencyDays
        self.logs = []
        self.stockCount = stockCount
        self.lowStockThreshold = lowStockThreshold
    }
}
