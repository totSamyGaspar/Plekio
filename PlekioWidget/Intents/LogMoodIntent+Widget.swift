//
//  LogMoodIntent+Widget.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 22.10.2026.
//

import AppIntents

// Never called: as a LiveActivityIntent it runs in the app (LogMoodIntent+Perform.swift).

extension LogMoodIntent {
    func perform() async throws -> some IntentResult { .result() }
}
