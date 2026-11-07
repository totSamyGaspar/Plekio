//
//  DoseEntry.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import WidgetKit

/// One moment of a widget's timeline: the snapshot as it looks at `date`.
/// Every widget reads the same entry and picks what it shows.
struct DoseEntry: TimelineEntry {
    let date: Date

    /// Nil when the app hasn't written one yet or it can't be read.
    let snapshot: WidgetSnapshot?

    var calendar: Calendar { .autoupdatingCurrent }

    // MARK: - State

    /// What the widget can say about `date`.
    enum State {
        /// No snapshot, or it doesn't reach this day: only the app can tell.
        case needsApp
        /// Nothing scheduled today.
        case empty
        case ready(WidgetSnapshot)
    }

    var state: State {
        guard let snapshot, snapshot.covers(date, calendar: calendar) else { return .needsApp }
        return snapshot.slotsOnDay(of: date, calendar: calendar).isEmpty ? .empty : .ready(snapshot)
    }
}
