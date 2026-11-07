//
//  LogDueDosesIntent.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import AppIntents

/// "Log my medications": takes the doses due now (`DueDoses.due`), for Siri and
/// Shortcuts. A LiveActivityIntent like the widget's buttons, so it runs in the app
/// (LogDueDosesIntentPerform.swift). In Shared so a Control Center button in the
/// widget extension can run it too.
///
/// `nonisolated` as a whole, unlike the widget's intents: it has no @Parameter.
nonisolated struct LogDueDosesIntent: LiveActivityIntent {

    static let title: LocalizedStringResource = "Log due medications"
    static let description = IntentDescription("Marks the medications due now as taken.")
    /// The answer names medications: only on an unlocked iPhone.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    init() {}
}
