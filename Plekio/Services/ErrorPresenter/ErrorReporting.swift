//
//  ErrorReporting.swift
//  Plekio
//
//  Where a failure goes once the code that hit it has nothing left to do about
//  it but tell the user.
//
//  A protocol, owned by the code that reports, so the reporter depends on it and
//  not on the UI. The storage layer reports a photo that did not reach disk; how
//  that becomes an alert is AppErrorPresenter's business, and the storage layer
//  never learns that AppErrorPresenter exists.
//

import Foundation

@MainActor
protocol ErrorReporting: AnyObject {
    func report(_ error: Error)
}

extension ErrorReporting {

    /// Runs a write and reports it if it fails.
    ///
    /// Returns `false` on failure, so the caller can keep the screen open, keep
    /// the form filled, and not pretend the data was saved.
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

    /// `run` for work that returns something: the value on success, nil after
    /// the error has been reported.
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
