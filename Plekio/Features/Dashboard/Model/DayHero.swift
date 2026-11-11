//
//  DayHero.swift
//  Plekio
//
//  Created by Edward Gasparian on 11.11.2026.
//

import Foundation

/// What the hero card at the top of Today shows for the selected day.
struct DayHero {
    /// The next open slot today; nil on other days and once nothing is left to take.
    /// Missed doses are left out, so the hero can't bypass the card's missed-dose lock.
    let upNext: [PillDose]?
    /// Today, and every dose is taken or skipped: the card turns over to the day's summary.
    let isDayComplete: Bool
    /// The card's front: the next slot, or once the day is done the last one, which is
    /// what the card was showing just before it turned. Nil hides the card.
    let front: [PillDose]?
    let takenCount: Int
    let totalCount: Int

    init(pills: [PillDose], selectedDate: Date, now: Date, calendar: Calendar) {
        let isToday = calendar.isDate(selectedDate, inSameDayAs: now)
        let sameSlot = { (time: Date) in
            pills.filter { calendar.isDate($0.time, equalTo: time, toGranularity: .minute) }
        }

        let earliest = pills
            .filter { $0.status == .pending && !$0.isMissed(at: now) }
            .map(\.time)
            .min()
        upNext = isToday ? earliest.map(sameSlot) : nil

        isDayComplete = isToday && !pills.isEmpty && pills.allSatisfy(\.status.isSettled)

        if let upNext {
            front = upNext
        } else if isDayComplete, let last = pills.map(\.time).max() {
            front = sameSlot(last)
        } else {
            front = nil
        }

        takenCount = pills.filter(\.isTaken).count
        totalCount = pills.count
    }
}
