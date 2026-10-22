//
//  QuickMood.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 22.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - QuickMood

/// The four moods the diary's Today card offers, with its emoji and labels.
struct QuickMood: Identifiable {
    let mood: WidgetSnapshot.Mood
    let emoji: String
    let label: LocalizedStringKey

    var id: WidgetSnapshot.Mood { mood }

    static var standard: [QuickMood] {
        [
            QuickMood(mood: .great, emoji: "☀️", label: "Great"),
            QuickMood(mood: .good, emoji: "🙂", label: "Good"),
            QuickMood(mood: .neutral, emoji: "😊", label: "Okay"),
            QuickMood(mood: .exhausted, emoji: "😴", label: "Tired")
        ]
    }
}
