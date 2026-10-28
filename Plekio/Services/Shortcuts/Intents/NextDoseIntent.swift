//
//  NextDoseIntent.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import AppIntents

/// "What's my next medication": reads the schedule, writes nothing.
nonisolated struct NextDoseIntent: AppIntent {

    static let title: LocalizedStringResource = "Next medication"
    static let description = IntentDescription("Tells which medications are next and when.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let upcoming = try ShortcutDoseActions.upcoming()
        return .result(dialog: IntentDialog(stringLiteral: ShortcutDialog.upcoming(upcoming, hidesDetails: ShortcutContext.hidesDetails)))
    }
}
