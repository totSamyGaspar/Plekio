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
    // There is deliberately no image property: photos live on disk (see ImageCache)
    // keyed by `id`, so a fetch for the schedule, statistics or notifications never
    // has to load image data it isn't going to render.
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
