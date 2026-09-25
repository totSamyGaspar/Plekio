//
//  SpyErrorReporter.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
@testable import Plekio

// MARK: - SpyErrorReporter

@MainActor
final class SpyErrorReporter: ErrorReporting {
    private(set) var reported: [Error] = []

    func report(_ error: Error) {
        reported.append(error)
    }
}
