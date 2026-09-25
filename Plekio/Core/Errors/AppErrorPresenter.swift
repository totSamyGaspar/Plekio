//
//  AppErrorPresenter.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import Observation

/// Turns a reported error into the text of the one alert MainTabView shows.
@Observable
@MainActor
final class AppErrorPresenter: ErrorReporting {

    // MARK: - Properties

    /// Text of the last error; nil means there is nothing to show.
    var message: String?

    /// Set from the error's `AlertTitled.alertTitle`, else a failed save.
    private(set) var title: LocalizedStringResource = AppErrorPresenter.defaultTitle

    private static let defaultTitle: LocalizedStringResource = "Couldn't save"

    // MARK: - Init

    init() {}

    // MARK: - ErrorReporting

    func report(_ error: Error) {
        title = (error as? AlertTitled)?.alertTitle ?? Self.defaultTitle
        message = Self.describe(error)
    }

    // MARK: - Helpers

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
