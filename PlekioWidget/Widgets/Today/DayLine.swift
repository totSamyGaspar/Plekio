//
//  DayLine.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

/// One line of the day under the card: a time-of-day heading, a medication, or
/// how many more didn't fit. Laid out like Today's timeline, a dose per line.
enum DayLine: Identifiable {
    case period(WidgetSnapshot.Period, slot: Date)
    case dose(WidgetSnapshot.Dose, slot: WidgetSnapshot.Slot)
    case more(Int)

    var id: String {
        switch self {
        case .period(let period, let slot): "period-\(period.rawValue)-\(slot.timeIntervalSince1970)"
        case .dose(let dose, let slot): "dose-\(dose.medicationId)-\(slot.time.timeIntervalSince1970)"
        case .more: "more"
        }
    }

    static let spacing: CGFloat = 4
    private static let headingHeight: CGFloat = 16
    static let doseHeight: CGFloat = 28
    private static let moreHeight: CGFloat = 14

    private var height: CGFloat {
        switch self {
        case .period: Self.headingHeight
        case .dose: Self.doseHeight
        case .more: Self.moreHeight
        }
    }

    /// The lines that fit `height`, around now. They start at the first slot with
    /// something still open (missed ones included), reach back to earlier slots
    /// while the whole rest of the day still fits, and end with "N more" when it doesn't.
    static func lines(for slots: [WidgetSnapshot.Slot], in snapshot: WidgetSnapshot,
                      at now: Date, height: CGFloat) -> [DayLine] {
        guard !slots.isEmpty else { return [] }
        let firstOpen = slots.firstIndex { slot in slot.doses.contains { $0.status == .pending } } ?? slots.count - 1

        var best = fill(slots[firstOpen...], height: height)
        var start = firstOpen
        while best.fitsAll, start > 0 {
            let earlier = fill(slots[(start - 1)...], height: height)
            guard earlier.fitsAll else { break }
            best = earlier
            start -= 1
        }
        return best.lines
    }

    /// Lines from these slots on, a heading where the time of day changes.
    private static func fill(_ slots: ArraySlice<WidgetSnapshot.Slot>, height: CGFloat) -> (lines: [DayLine], fitsAll: Bool) {
        let doses = slots.flatMap { slot in slot.doses.map { (slot, $0) } }
        var lines: [DayLine] = []
        var used: CGFloat = 0
        var period: WidgetSnapshot.Period?

        for (index, (slot, dose)) in doses.enumerated() {
            var next: [DayLine] = []
            if slot.period != period { next.append(.period(slot.period, slot: slot.time)) }
            next.append(.dose(dose, slot: slot))

            let cost = next.reduce(0) { $0 + $1.height + spacing }
            let left = doses.count - index - 1
            // Keep room for "N more" unless this is the last dose.
            let reserve = left > 0 ? moreHeight + spacing : 0
            guard used + cost + reserve <= height + spacing else {
                lines.append(.more(doses.count - index))
                return (lines, false)
            }
            lines += next
            used += cost
            period = slot.period
        }
        return (lines, true)
    }
}
