//
//  ToggleDoseIntentPerform.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import AppIntents

extension ToggleDoseIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        if taken {
            await WidgetDoseActions.take(ids, at: slot)
        } else {
            await WidgetDoseActions.untake(ids, at: slot)
        }
        return .result()
    }
}
