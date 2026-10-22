//
//  SkipDosesIntent+Perform.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import AppIntents

extension SkipDosesIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        await WidgetDoseActions.skip(ids, at: slot)
        return .result()
    }
}
