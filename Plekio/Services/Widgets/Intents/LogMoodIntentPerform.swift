//
//  LogMoodIntentPerform.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import AppIntents

extension LogMoodIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        await WidgetDiaryActions.logMood(mood)
        return .result()
    }
}
