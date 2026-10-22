//
//  WidgetSnapshot+DiaryDay.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Foundation

// MARK: - DiaryDay

extension WidgetSnapshot {

    nonisolated struct DiaryDay: Codable, Equatable, Sendable {
        var checkInDate: Date
        var mood: Mood
        /// Logged with a mood only: energy, sleep and water are defaults, not answers.
        var isQuickLog: Bool
        var energyLevel: Int
        var sleepHours: Double
        var waterGlasses: Int
    }
}
