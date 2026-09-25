//
//  ErrorReporting.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - ErrorReporting

@MainActor
protocol ErrorReporting: AnyObject {
    func report(_ error: Error)
}

// MARK: - AlertTitled

/// An error that names its own alert title. Anything else is shown as a failed save.
protocol AlertTitled: Error {
    var alertTitle: LocalizedStringResource { get }
}

// MARK: - Running Work

extension ErrorReporting {

    /// Runs a write and reports any error. False on failure, so the caller keeps the form open.
    @discardableResult
    func run(_ work: () throws -> Void) -> Bool {
        do {
            try work()
            return true
        } catch {
            report(error)
            return false
        }
    }

    /// Like `run`, returning the value; nil after the error has been reported.
    @discardableResult
    func attempt<T>(_ work: () throws -> T) -> T? {
        do {
            return try work()
        } catch {
            report(error)
            return nil
        }
    }
}
