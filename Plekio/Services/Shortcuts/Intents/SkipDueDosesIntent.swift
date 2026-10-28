//
//  SkipDueDosesIntent.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import AppIntents

/// "Skip my medications": skips the doses due now (`DueDoses.due`).
nonisolated struct SkipDueDosesIntent: AppIntent {

    static let title: LocalizedStringResource = "Skip due medications"
    static let description = IntentDescription("Marks the medications due now as skipped.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let slot = try await ShortcutDoseActions.skipDue() else {
            return .result(dialog: IntentDialog(ShortcutDialog.nothingDue))
        }
        return .result(dialog: IntentDialog(ShortcutDialog.skipped(slot, hidesDetails: ShortcutContext.hidesDetails)))
    }
}
