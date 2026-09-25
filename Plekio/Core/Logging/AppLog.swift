//
//  AppLog.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import OSLog

// MARK: - AppLog

/// `nonisolated` because the project defaults to main-actor isolation and the
/// loggers are also used from background queues.
nonisolated enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? AppBrand.name

    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let media = Logger(subsystem: subsystem, category: "media")
}
