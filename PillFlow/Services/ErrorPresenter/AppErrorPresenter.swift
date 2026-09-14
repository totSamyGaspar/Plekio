//
//  AppErrorPresenter.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//
//  Single place where storage write errors are shown.
//
//  DatabaseService throws instead of swallowing `try? context.save()`, but a
//  save failure looks the same on every screen and needs no per-screen
//  behaviour. Rather than repeat the same `.alert` in seven views, the alert
//  lives once in MainTabView and view models run the write through `run`.
//

import SwiftUI
import Combine

@MainActor
final class AppErrorPresenter: ObservableObject {

    static let shared = AppErrorPresenter()

    /// Text of the last error; nil means there is nothing to show.
    @Published var message: String?

    private init() {}

    /// Runs a write operation and surfaces the error if it fails.
    ///
    /// Returns `false` on failure, so the caller can keep the screen open, keep
    /// the form filled, and not pretend the data was saved.
    @discardableResult
    func run(_ work: () throws -> Void) -> Bool {
        do {
            try work()
            return true
        } catch {
            message = Self.describe(error)
            return false
        }
    }

    /// Surfaces an error for work that cannot be wrapped in `run`: a failure
    /// AFTER a successful commit, where there is no operation left to fail and
    /// nothing for the caller to abandon.
    func report(_ error: Error) {
        message = Self.describe(error)
    }

    private static func describe(_ error: Error) -> String {
        guard let localized = error as? LocalizedError,
              let description = localized.errorDescription else {
            return error.localizedDescription
        }
        if let reason = localized.failureReason, !reason.isEmpty {
            return "\(description)\n\n\(reason)"
        }
        return description
    }
}
