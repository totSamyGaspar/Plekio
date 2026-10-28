//
//  ShortcutDialog.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Foundation

/// What Siri says after a shortcut. With `hidesDetails` (Plekio's Face ID lock on)
/// only times are said: no medication names, no readings.
enum ShortcutDialog {

    static let nothingDue: LocalizedStringResource = "Nothing is due right now."

    static func logged(_ slot: DueDoses.Slot, hidesDetails: Bool) -> LocalizedStringResource {
        hidesDetails ? "Logged the doses due at \(time(slot))." : "Logged \(names(slot))."
    }

    static func skipped(_ slot: DueDoses.Slot, hidesDetails: Bool) -> LocalizedStringResource {
        hidesDetails ? "Skipped the doses due at \(time(slot))." : "Skipped \(names(slot))."
    }

    static func readingSaved(systolic: Int, diastolic: Int, hidesDetails: Bool) -> LocalizedStringResource {
        let pressure = "\(systolic)/\(diastolic)"
        return hidesDetails ? "Reading saved." : "Reading saved: \(pressure)."
    }

    /// A missed slot first, as it is the one to act on; then what comes next.
    static func upcoming(_ upcoming: DueDoses.Upcoming, hidesDetails: Bool) -> String {
        if hidesDetails {
            return String(localized: "Open Plekio to see your next medications.")
        }
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
