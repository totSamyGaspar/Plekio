//
//  LogMoodIntent.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import AppIntents
import Foundation

// MARK: - LogMoodIntent

/// A mood tapped on the diary widget. Like the dose buttons, a LiveActivityIntent
/// run in the app (LogMoodIntent+Perform.swift), where QuickMoodLogging keeps it to
/// one entry a day, exactly as the diary's Today card does.
struct LogMoodIntent: LiveActivityIntent {

    nonisolated static let title: LocalizedStringResource = "Log mood"
    nonisolated static let isDiscoverable = false

    /// `DiaryMood`'s stored raw value.
    @Parameter(title: "Mood") var mood: String

    init() {}

    init(_ mood: WidgetSnapshot.Mood) {
        self.mood = mood.rawValue
    }
}
