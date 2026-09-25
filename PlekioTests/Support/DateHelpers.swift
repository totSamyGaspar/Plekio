//
//  DateHelpers.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 22.08.2026.
//

import Foundation

// MARK: - Date builders

/// A date/time in the current calendar, for tests where local hour/day matters.
func testDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    comps.second = 0
    return Calendar.current.date(from: comps)!
}

func addingDays(_ days: Int, to date: Date) -> Date {
    Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
}
