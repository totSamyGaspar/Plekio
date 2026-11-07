//
//  DueDoses.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Foundation

/// What "log my medications" and "what's next" mean at a given moment, for Siri
/// and Shortcuts. Pure: the caller reads the schedule.
nonisolated enum DueDoses {

    /// The open doses of one time of day.
    struct Slot: Equatable, Sendable {
        let time: Date
        let doses: [PillDose]
    }

    struct Upcoming: Equatable, Sendable {
        /// The earliest open slot today that isn't missed yet.
        var next: Slot?
        /// The latest missed slot today, still worth taking.
        var missed: Slot?
        /// Tomorrow's first slot, when nothing is left today.
        var tomorrow: Slot?
    }

    /// How early a slot counts as due: as long as the grace after it.
    static let lead = DoseSchedule.missedGrace

    /// The slot nearest to now with something still open: one that has come and isn't
    /// missed yet, else one starting within `lead`, else the latest missed one (late
    /// doses still count, as on Today). So at 22:00 with 08:00 missed and 22:30
    /// ahead, it is the evening that gets logged. Nil when nothing is due.
    /// - Parameter pills: one day's schedule, as `fetchPills(for:)` returns it.
    static func due(in pills: [PillDose], at now: Date) -> Slot? {
        let open = openSlots(pills)
        let past = open.filter { $0.time <= now }
        return past.last { !isMissed($0, at: now) }
            ?? open.first { $0.time > now && $0.time <= now.addingTimeInterval(lead) }
            ?? past.last
    }

    static func upcoming(today: [PillDose], tomorrow: [PillDose], at now: Date) -> Upcoming {
        let open = openSlots(today)
        let next = open.first { !isMissed($0, at: now) }
        return Upcoming(
            next: next,
            missed: open.last { isMissed($0, at: now) },
            tomorrow: next == nil ? openSlots(tomorrow).first : nil
        )
    }

    /// Pending doses grouped by exact time, in time order, names sorted within a slot.
    static func openSlots(_ pills: [PillDose]) -> [Slot] {
        Dictionary(grouping: pills.filter { $0.status == .pending }, by: \.time)
            .map { Slot(time: $0.key, doses: $0.value.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) }
            .sorted { $0.time < $1.time }
    }

    private static func isMissed(_ slot: Slot, at now: Date) -> Bool {
        slot.doses.contains { $0.isMissed(at: now) }
    }
}
