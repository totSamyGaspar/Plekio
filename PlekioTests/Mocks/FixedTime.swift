//
//  FixedTime.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
@testable import Plekio

// MARK: - FixedTime

nonisolated final class FixedTime: TimeSource, @unchecked Sendable {
    var now: Date
    /// Should match the calendar `testDate` uses, so "today" agrees with the test.
    var calendar: Calendar

    init(_ now: Date, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
