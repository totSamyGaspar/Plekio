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

    init(_ now: Date) {
        self.now = now
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
