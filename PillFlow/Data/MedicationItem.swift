//
//  MedicationItem.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

@Model
final class MedicationItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var formSystemImage: String
    var dosage: Int
    var timesOfDay: [Date]
    var frequencyDays: Int
    var course: TreatmentCourse?
    // Photos are stored on disk (see ImageCache), keyed by this medication's
    // `id`, rather than as a blob field on the model — that way every fetch
    // (schedule, statistics, notifications, etc.) doesn't have to load image
    // data it isn't going to render.
    var stockCount: Int
    var lowStockThreshold: Int

    @Relationship(deleteRule: .cascade, inverse: \DoseLog.medication)
    var logs: [DoseLog]

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
