//
//  WidgetSnapshot+Reading.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

// MARK: - Day

/// The snapshot as seen at one moment: what Today would show if it were open.
/// Every rule here matches DashboardView, so the widget and the app agree.
nonisolated extension WidgetSnapshot {

    /// The slots on the day of `date`, in time order.
    func slotsOnDay(of date: Date, calendar: Calendar) -> [Slot] {
        slots.filter { calendar.isDate($0.time, inSameDayAs: date) }
    }

    /// Taken doses and all doses on the day of `date`. Skipped count in the total,
    /// as on Today's "3 of 5 doses logged".
    func progress(onDayOf date: Date, calendar: Calendar) -> (taken: Int, total: Int) {
        let doses = slotsOnDay(of: date, calendar: calendar).flatMap(\.doses)
        return (doses.filter { $0.status == .taken }.count, doses.count)
    }

    /// Every dose of the day is taken or skipped: the hero card's "Day complete".
    func isDayComplete(at date: Date, calendar: Calendar) -> Bool {
        let doses = slotsOnDay(of: date, calendar: calendar).flatMap(\.doses)
        return !doses.isEmpty && doses.allSatisfy(\.status.isSettled)
    }

    // MARK: - Up next

    /// The earliest slot today with a dose that is pending and not yet missed.
    /// Missed doses are left out, as on the hero card: they have a widget of their own.
    func upNext(at now: Date, calendar: Calendar) -> Slot? {
        slotsOnDay(of: now, calendar: calendar)
            .first { slot in
                slot.doses.contains { $0.status == .pending } && !isPastGrace(slot, at: now)
            }
    }

    /// The first slot of the next day that has one, for "Tomorrow from 08:00".
    func firstSlot(afterDayOf date: Date, calendar: Calendar) -> Slot? {
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        return slots.first { $0.time >= startOfNextDay }
    }

    // MARK: - Missed

    /// Today's slots with a pending dose past the grace period, latest first:
    /// the most recent one is the one still worth taking.
    func missed(at now: Date, calendar: Calendar) -> [Slot] {
        slotsOnDay(of: now, calendar: calendar)
            .filter { slot in isPastGrace(slot, at: now) && slot.doses.contains { $0.status == .pending } }
            .reversed()
    }

    func isMissed(_ dose: Dose, in slot: Slot, at now: Date) -> Bool {
        dose.status == .pending && isPastGrace(slot, at: now)
    }

    private func isPastGrace(_ slot: Slot, at now: Date) -> Bool {
        now > slot.time.addingTimeInterval(missedGrace)
    }

    // MARK: - Logging

    /// Past, or later today; future days can't be logged in advance (`PillDose.isLoggable`).
    func canLog(_ slot: Slot, at now: Date, calendar: Calendar) -> Bool {
        slot.time <= now || calendar.isDate(slot.time, inSameDayAs: now)
    }

    // MARK: - Timeline

    /// The moments after `now` at which the widget looks different with no new data:
    /// each slot (up next moves on), each slot's grace end (a dose turns missed),
    /// and each midnight (the day rolls over). Sorted, without duplicates.
    func changeDates(after now: Date, calendar: Calendar) -> [Date] {
        var dates = Set<Date>()
        for slot in slots {
            dates.insert(slot.time)
            // +1 s: `isPastGrace` is strict, so at the grace end itself the dose isn't missed yet.
            dates.insert(slot.time.addingTimeInterval(missedGrace + 1))
        }
        let today = calendar.startOfDay(for: now)
        for offset in 1...2 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: today) {
                dates.insert(midnight)
            }
        }
        return dates.filter { $0 > now }.sorted()
    }
}
