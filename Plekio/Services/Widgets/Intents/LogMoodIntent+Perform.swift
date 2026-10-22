//
//  LogMoodIntent+Perform.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import AppIntents

// The diary widget's mood buttons, in the app's process (see Shared/Widget/Intents/LogMoodIntent.swift).

extension LogMoodIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        await WidgetDiaryActions.logMood(mood)
        return .result()
    }
}
