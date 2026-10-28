//
//  PlekioShortcuts.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import AppIntents

/// Phrases Siri knows without setup; translated in AppShortcuts.xcstrings.
/// Each must name the app.
nonisolated struct PlekioShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogDueDosesIntent(),
            phrases: [
                "Log my medications in \(.applicationName)",
                "Log my pills in \(.applicationName)"
            ],
            shortTitle: "Log medications",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: NextDoseIntent(),
            phrases: [
                "What's my next medication in \(.applicationName)",
                "Next dose in \(.applicationName)"
            ],
            shortTitle: "Next medication",
            systemImageName: "clock"
        )
        AppShortcut(
            intent: SkipDueDosesIntent(),
            phrases: [
                "Skip my medications in \(.applicationName)"
            ],
            shortTitle: "Skip medications",
            systemImageName: "forward"
        )
    }
}
