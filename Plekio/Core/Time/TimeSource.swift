//
//  TimeSource.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - TimeSource

nonisolated protocol TimeSource: Sendable {
    var now: Date { get }
    /// The calendar "today", "this week" and "midnight" are counted in.
    var calendar: Calendar { get }
}

// MARK: - SystemTime

/// The real clock, in the user's calendar and time zone.
nonisolated struct SystemTime: TimeSource {
    init() {}
    var now: Date { Date() }
    /// Autoupdating, so a time-zone change while running is picked up.
    var calendar: Calendar { .autoupdatingCurrent }
}
