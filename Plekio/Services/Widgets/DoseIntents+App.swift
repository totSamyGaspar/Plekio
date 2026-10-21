//
//  DoseIntents+App.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import AppIntents

// The widget buttons' work, in the app's process (see Shared/Widget/DoseIntents.swift).
// On the main actor, where the dose logging lives; allowed for an async requirement.

extension TakeDosesIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        await WidgetDoseActions.take(ids, at: slot)
        return .result()
    }
}

extension SkipDosesIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        await WidgetDoseActions.skip(ids, at: slot)
        return .result()
    }
}
