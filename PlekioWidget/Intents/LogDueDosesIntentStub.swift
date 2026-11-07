//
//  LogDueDosesIntentStub.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 22.10.2026.
//

import AppIntents

// Never called: as a LiveActivityIntent it runs in the app. Hidden from Shortcuts
// here, so the action isn't listed twice: once for the app, once for the extension.

extension LogDueDosesIntent {
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        .result()
    }
}
