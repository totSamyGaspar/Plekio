//
//  BackgroundRefresh.swift
//  Plekio
//
//  Created by Edward Gasparian on 09.11.2026.
//

import BackgroundTasks
import Foundation
import os

/// Rebuilds the reminder queue while Plekio isn't opened: it is planned ahead within
/// iOS's 64 requests and would otherwise run out after a week or two. iOS decides
/// when, and rarely for an app that isn't opened, so the last day's reminders also
/// ask for the app to be opened.
@MainActor
enum BackgroundRefresh {

    /// Also in Info.plist, BGTaskSchedulerPermittedIdentifiers.
    static let identifier = "com.EdHasp.Plekio.reminders"

    /// Before launch ends: iOS requires the handler registered by then.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            MainActor.assumeIsolated { run(task) }
        }
    }

    /// A day ahead at the earliest: the queue covers a week or more.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Always on the Simulator; on a device when Background App Refresh is off.
            AppLog.notifications.info("Background refresh not scheduled: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func run(_ task: BGTask) {
        // Used from the work and its expiration alike; iOS calls both on the main queue.
        nonisolated(unsafe) let task = task
        schedule()

        // Reading `launcher` opens the store if this launch came from the refresh.
        guard let dependencies = AppDelegate.shared?.launcher.dependencies else {
            task.setTaskCompleted(success: false)
            return
        }

        let work = Task {
            await dependencies.reminderSync.sync().value
            await dependencies.widgetSnapshots.refresh().value
            task.setTaskCompleted(success: !Task.isCancelled)
        }
        task.expirationHandler = { work.cancel() }
    }
}
