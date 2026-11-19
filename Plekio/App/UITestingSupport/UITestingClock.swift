//
//  UITestingClock.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.11.2026.
//

#if DEBUG
import Foundation

// MARK: - UITestingClock

/// A clock that starts at a chosen moment and then runs at normal speed.
/// Not frozen: the undo window, the banner's countdown and the grace hour all
/// measure elapsed time, and a stopped clock would leave them hanging.
nonisolated struct UITestingClock: TimeSource {

    /// How far this clock is from the real one, fixed at launch.
    private let offset: TimeInterval

    init(startingAt start: Date, realNow: Date = Date()) {
        offset = start.timeIntervalSince(realNow)
    }

    var now: Date { Date().addingTimeInterval(offset) }

    /// The device's own calendar: `-ui-now` is read as wall-clock time in its zone.
    var calendar: Calendar { .autoupdatingCurrent }
}
#endif
