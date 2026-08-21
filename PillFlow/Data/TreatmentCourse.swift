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
    
    // Каскадное удаление: удаляем курс -> удаляются все его медикаменты
    @Relationship(deleteRule: .cascade, inverse: \MedicationItem.course)
    var medications: [MedicationItem]
    
    init(name: String, startDate: Date, endDate: Date) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.medications = []
    }
}
