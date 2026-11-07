//
//  TakeDosesIntentStub.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import AppIntents

// Never called: as LiveActivityIntents these run in the app.
// They exist so the widget can build its buttons; the store isn't reachable from here.

extension TakeDosesIntent {
    func perform() async throws -> some IntentResult { .result() }
}
