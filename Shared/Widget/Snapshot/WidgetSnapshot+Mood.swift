//
//  WidgetSnapshot+Mood.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Foundation

// MARK: - Mood

extension WidgetSnapshot {

    /// Mirrors `DiaryMood`'s stored raw values.
    nonisolated enum Mood: String, Codable, Sendable, CaseIterable {
        case great = "Great"
        case good = "Good"
        case neutral = "Neutral"
        case downLow = "Down / Low"
        case stressed = "Stressed"
        case exhausted = "Exhausted"
        case inPain = "In Pain"

        /// A mood a newer app added reads as neutral instead of failing the snapshot.
        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Mood(rawValue: raw) ?? .neutral
        }

        /// As the diary shows a logged mood (`DiaryMood.emoji`).
        var emoji: String {
            switch self {
            case .great: "⭐"
            case .good: "😊"
            case .neutral: "😐"
            case .downLow: "😔"
            case .stressed: "⚡"
            case .exhausted: "😴"
            case .inPain: "🩹"
            }
        }
    }
}
