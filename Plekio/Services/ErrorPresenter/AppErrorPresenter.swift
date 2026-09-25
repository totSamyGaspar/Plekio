//
//  AppErrorPresenter.swift
//  Plekio
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

import Foundation
import Observation

/// Turns a reported error into the text of the one alert MainTabView shows.
///
/// No longer a singleton: the composition root owns the instance and hands it,
/// as `any ErrorReporting`, to whatever reports — view models and the storage
/// layer alike. `@Observable` so the alert follows `message` without Combine.
@Observable
@MainActor
final class AppErrorPresenter: ErrorReporting {

    /// Text of the last error; nil means there is nothing to show.
    var message: String?

    /// The alert's title. Most failures are writes; a failed read is not a
    /// "couldn't save", and saying so would send the user looking for an edit
    /// that never happened.
    private(set) var title: LocalizedStringResource = "Couldn't save"

    init() {}

    func report(_ error: Error) {
        if case DatabaseError.readFailed = error {
            title = "Couldn't load your data"
        } else {
            title = "Couldn't save"
        }
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
