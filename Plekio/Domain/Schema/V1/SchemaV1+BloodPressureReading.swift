//
//  SchemaV1+BloodPressureReading.swift
//  Plekio
//
//  Created by Edward Gasparian on 30.08.2026.
//

import Foundation
import SwiftData

// MARK: - BloodPressureReading

nonisolated extension SchemaV1 {

    /// `nonisolated`: BackgroundReader reads it on a background context.
    @Model
    nonisolated final class BloodPressureReading {

        // MARK: - Properties

        @Attribute(.unique) var id: UUID

        var measuredAt: Date
        var systolic: Int
        var diastolic: Int
        var pulse: Int?

        // MARK: - Init

        init(
            id: UUID = UUID(),
            measuredAt: Date,
            systolic: Int,
            diastolic: Int,
            pulse: Int? = nil
        ) {
            self.id = id
            self.measuredAt = measuredAt
            self.systolic = systolic
            self.diastolic = diastolic
            self.pulse = pulse
        }
    }
}
