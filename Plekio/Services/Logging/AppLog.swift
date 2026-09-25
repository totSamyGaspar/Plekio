//
//  AppLog.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//
//  Logging categories instead of print().
//
//  print() writes in release builds too, cannot be filtered, has no levels
//  and — worse — inside catch blocks it was the only "handling" an error
//  got. os.Logger gives levels and categories and keeps private data out of
//  the shared log.
//

import Foundation
import OSLog

/// `nonisolated` for the same reason as ImageCache: the project builds with
/// default main-actor isolation, so these static properties would become
/// `@MainActor` — but the logger is also called from background queues, which
/// is exactly where the disk work happens.
nonisolated enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? AppBrand.name

    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let media = Logger(subsystem: subsystem, category: "media")
}
