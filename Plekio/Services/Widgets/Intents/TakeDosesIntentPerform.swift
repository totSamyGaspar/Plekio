//
//  TakeDosesIntentPerform.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import AppIntents

// On the main actor, where the dose logging lives; allowed for an async requirement.

extension TakeDosesIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        await WidgetDoseActions.take(ids, at: slot)
        return .result()
    }
}
