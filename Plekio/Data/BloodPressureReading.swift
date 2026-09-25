//
//  BloodPressureReading.swift
//  Plekio
//

import Foundation
import SwiftData

@Model
final class BloodPressureReading {
    @Attribute(.unique) var id: UUID

    var measuredAt: Date
    var systolic: Int
    var diastolic: Int
    var pulse: Int?
    
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

extension BloodPressureReading {
    static let systolicRange = 60...300
    static let diastolicRange = 30...200
    static let pulseRange = 30...220

    static func isOrdered(systolic: Int, diastolic: Int) -> Bool {
        systolic > diastolic
    }

    var formattedPressure: String {
        "\(systolic)/\(diastolic)"
    }
}
