//
//  DateHelpers.swift
//  PillFlowTests
//
//  Shared helper for constructing specific dates/times in tests
//  (Calendar.current + DateComponents), factored out to avoid duplicating
//  this code in every test file.
//

import Foundation

/// Builds a specific date/time in the current calendar — useful for tests
/// where the weekday/hour/minute matters, not the absolute timestamp.
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
