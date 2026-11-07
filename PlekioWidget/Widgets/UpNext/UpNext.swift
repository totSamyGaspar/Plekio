//
//  UpNext.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

/// What the "Up next" widget shows at one moment. The order matches Today: the
/// next open slot first; a missed one only when nothing is ahead; then the day's summary.
enum UpNext {
    case next(WidgetSnapshot.Slot)
    case missed(WidgetSnapshot.Slot)
    case complete
    case empty(tomorrow: WidgetSnapshot.Slot?)
    case needsApp

    init(_ entry: DoseEntry) {
        switch entry.state {
        case .needsApp:
            self = .needsApp
        case .empty:
            self = .empty(tomorrow: entry.snapshot?.firstSlot(afterDayOf: entry.date, calendar: entry.calendar))
        case .ready(let snapshot):
            if let next = snapshot.upNext(at: entry.date, calendar: entry.calendar) {
                self = .next(next)
            } else if let missed = snapshot.missed(at: entry.date, calendar: entry.calendar).first {
                self = .missed(missed)
            } else {
                self = .complete
            }
        }
    }

    /// Where a tap opens the app: the take-dose sheet for the slot shown, else Today.
    var link: WidgetLink {
        switch self {
        case .next(let slot), .missed(let slot): slot.openLink
        case .complete, .empty, .needsApp: .today
        }
    }
}
