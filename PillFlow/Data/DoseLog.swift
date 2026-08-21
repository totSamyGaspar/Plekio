//
//  DoseLog.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

@Model
final class DoseLog {
    @Attribute(.unique) var id: UUID
    var scheduledTime: Date
    var actualTakeTime: Date?
    var isTaken: Bool
    
    var medication: MedicationItem?
    
    init(scheduledTime: Date, isTaken: Bool) {
        self.id = UUID()
        self.scheduledTime = scheduledTime
        self.isTaken = isTaken
    }
}
