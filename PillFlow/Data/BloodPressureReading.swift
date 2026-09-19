//
//  BloodPressureReading.swift
//  PillFlow
//

import Foundation
import SwiftData

/// One blood-pressure measurement.
///
/// Deliberately its own record rather than fields on `DiaryEntry`: pressure is
/// commonly measured morning and evening, while a check-in happens once a day.
/// Hanging it off the entry would have made the second measurement overwrite the
/// first — and a doctor reading the history needs both, with their times.
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
    
    /// Plausible ranges, used to clamp the input. Wide on purpose: the point is
    /// to stop typos like 1200/80 from poisoning the chart, not to decide which
    /// readings are medically sensible.
    static let systolicRange = 60...300
    static let diastolicRange = 30...200
    static let pulseRange = 30...220

    var formattedPressure: String {
        "\(systolic)/\(diastolic)"
    }
}
