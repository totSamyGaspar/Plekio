//
//  FixedTime.swift
//  PlekioTests
//
//  A clock that says whatever the test tells it, and moves only when asked.
//

import Foundation
@testable import Plekio

nonisolated final class FixedTime: TimeSource, @unchecked Sendable {
    var now: Date
    /// The calendar the test helpers build dates in (`testDate`), so "today"
    /// here and in the test agree. The test run pins its time zone and region
    /// — see TestEnvironmentTests.
    var calendar: Calendar

    init(_ now: Date, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
