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

/// The rules live in BloodPressureRules, shared with the entry form; these
/// names stay for the store and the existing tests.
extension BloodPressureReading {
    static var systolicRange: ClosedRange<Int> { BloodPressureRules.systolicRange }
    static var diastolicRange: ClosedRange<Int> { BloodPressureRules.diastolicRange }
    static var pulseRange: ClosedRange<Int> { BloodPressureRules.pulseRange }

    static func isOrdered(systolic: Int, diastolic: Int) -> Bool {
        BloodPressureRules.isOrdered(systolic: systolic, diastolic: diastolic)
    }
}
