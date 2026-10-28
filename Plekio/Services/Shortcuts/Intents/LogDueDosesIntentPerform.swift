//
//  LogDueDosesIntentPerform.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import AppIntents

extension LogDueDosesIntent {
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let slot = try await ShortcutDoseActions.takeDue() else {
            return .result(dialog: IntentDialog(ShortcutDialog.nothingDue))
        }
        return .result(dialog: IntentDialog(ShortcutDialog.logged(slot, hidesDetails: ShortcutContext.hidesDetails)))
    }
}
