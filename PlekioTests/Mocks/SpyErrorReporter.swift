//
//  SpyErrorReporter.swift
//  PlekioTests
//
//  Stands in for AppErrorPresenter now that view models take their error
//  reporter through init instead of reaching for a shared one. Records what
//  was reported, so a test can assert a failure was surfaced rather than
//  swallowed.
//

import Foundation
@testable import Plekio

@MainActor
final class SpyErrorReporter: ErrorReporting {
    private(set) var reported: [Error] = []

    func report(_ error: Error) {
        reported.append(error)
    }
}
