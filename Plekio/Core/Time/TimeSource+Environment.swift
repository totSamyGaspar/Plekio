//
//  TimeSource+Environment.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.11.2026.
//

import SwiftUI

// MARK: - Environment

private nonisolated struct TimeSourceKey: EnvironmentKey {
    /// The real clock; the root injects the app's own, which a UI-testing launch
    /// or a test can replace.
    static let defaultValue: any TimeSource = SystemTime()
}

extension EnvironmentValues {
    /// "Now" and the calendar, for views. Views read this, never `Date()` or
    /// `Calendar.current`, so the whole app agrees on the time and a test can fix it.
    nonisolated var timeSource: any TimeSource {
        get { self[TimeSourceKey.self] }
        set { self[TimeSourceKey.self] = newValue }
    }
}
