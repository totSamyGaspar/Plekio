//
//  WidgetSnapshot+BloodPressureReading.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Foundation

// MARK: - Reading

extension WidgetSnapshot {

    /// Values only: like the app, the widget never labels a reading normal or high.
    nonisolated struct Reading: Codable, Equatable, Sendable, Identifiable {
        var measuredAt: Date
        var systolic: Int
        var diastolic: Int
        var pulse: Int?

        var id: Date { measuredAt }
    }
}
