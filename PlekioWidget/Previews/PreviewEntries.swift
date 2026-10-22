//
//  PreviewEntries.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

#if DEBUG
import SwiftUI
import WidgetKit

/// The states each widget steps through in its preview timeline.
enum PreviewEntries {
    static let calendar = Calendar.autoupdatingCurrent
    static let today = calendar.startOfDay(for: .now)

    static func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
    }

    /// Generated at 07:00, so every entry below is within its two days.
    static let sample = WidgetSnapshot.sample(at: at(7))

    /// Morning up next, at 07:30.
    static let morning = DoseEntry(date: at(7, 30), snapshot: sample)
    /// Afternoon up next, morning taken.
    static let afternoon = DoseEntry(date: at(13, 30), snapshot: sample)
    /// 15:30: the 14:00 dose is missed, evening is up next.
    static let missedBehind = DoseEntry(date: at(15, 30), snapshot: sample)
    /// 22:00 with evening still open: only the missed card is left.
    static let missed = DoseEntry(date: at(22), snapshot: sample)

    static let complete: DoseEntry = {
        var done = sample
        for index in done.slots.indices where calendar.isDate(done.slots[index].time, inSameDayAs: today) {
            for dose in done.slots[index].doses.indices { done.slots[index].doses[dose].status = .taken }
        }
        return DoseEntry(date: at(21), snapshot: done)
    }()

    static let empty: DoseEntry = {
        var nothing = sample
        nothing.slots.removeAll { calendar.isDate($0.time, inSameDayAs: today) }
        return DoseEntry(date: at(9), snapshot: nothing)
    }()

    static let needsApp = DoseEntry(date: .now, snapshot: nil)

    static let diaryLogged: DoseEntry = {
        var logged = sample
        logged.diary = WidgetSnapshot.DiaryDay(checkInDate: at(9, 15), mood: .good, isQuickLog: false,
                                               energyLevel: 4, sleepHours: 7.5, waterGlasses: 6)
        return DoseEntry(date: at(10), snapshot: logged)
    }()

    static let diaryQuickLog: DoseEntry = {
        var logged = sample
        logged.diary = WidgetSnapshot.DiaryDay(checkInDate: at(9, 15), mood: .exhausted, isQuickLog: true,
                                               energyLevel: 4, sleepHours: 7.5, waterGlasses: 6)
        return DoseEntry(date: at(10), snapshot: logged)
    }()

    static let noReadings: DoseEntry = {
        var empty = sample
        empty.bloodPressure = []
        return DoseEntry(date: at(9), snapshot: empty)
    }()

    static let allStocked: DoseEntry = {
        var stocked = sample
        stocked.lowStock = []
        return DoseEntry(date: at(9), snapshot: stocked)
    }()
}
#endif
