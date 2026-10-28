//
//  ShortcutDialog.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Foundation

/// What Siri says after a dose shortcut.
enum ShortcutDialog {

    static let nothingDue: LocalizedStringResource = "Nothing is due right now."

    static func logged(_ slot: DueDoses.Slot) -> LocalizedStringResource {
        "Logged \(names(slot))."
    }

    static func skipped(_ slot: DueDoses.Slot) -> LocalizedStringResource {
        "Skipped \(names(slot))."
    }

    /// A missed slot first, as it is the one to act on; then what comes next.
    static func upcoming(_ upcoming: DueDoses.Upcoming) -> String {
        var sentences: [String] = []
        if let missed = upcoming.missed {
            sentences.append(String(localized: "Missed at \(time(missed)): \(names(missed))."))
        }
        if let next = upcoming.next {
            sentences.append(String(localized: "Next at \(time(next)): \(names(next))."))
        } else if let tomorrow = upcoming.tomorrow {
            sentences.append(String(localized: "Nothing more today. Tomorrow at \(time(tomorrow)): \(names(tomorrow))."))
        } else if sentences.isEmpty {
            sentences.append(String(localized: "No medications are scheduled."))
        }
        return sentences.joined(separator: " ")
    }

    private static func names(_ slot: DueDoses.Slot) -> String {
        slot.doses.map(\.name).formatted(.list(type: .and))
    }

    private static func time(_ slot: DueDoses.Slot) -> String {
        slot.time.formatted(date: .omitted, time: .shortened)
    }
}
