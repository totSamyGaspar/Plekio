//
//  WidgetDoseActions.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import UIKit
import os

// MARK: - WidgetDoseActions

/// Carries out a widget button in the app. Hands it to NotificationResponseHandler,
/// as a notification's Take or Skip would be: same rules, same reminder rebuild.
@MainActor
enum WidgetDoseActions {

    static func take(_ ids: [UUID], at slot: Date) async {
        await run(ids) { dependencies, afterWrite in
            await dependencies.notificationResponses.handle(.take(medicationIds: ids, slot: slot), afterWrite: afterWrite)
        }
    }

    static func skip(_ ids: [UUID], at slot: Date) async {
        await run(ids) { dependencies, afterWrite in
            await dependencies.notificationResponses.handle(.skip(medicationIds: ids, slot: slot), afterWrite: afterWrite)
        }
    }

    /// A check taken back on the widget: un-logs the dose as Today's checkbox does,
    /// returning its stock and its reminder.
    static func untake(_ ids: [UUID], at slot: Date) async {
        await run(ids) { dependencies, afterWrite in
            let taken = dependencies.database.fetchPills(for: slot, preFetchedCourses: nil)
                .filter { ids.contains($0.medicationId) && abs($0.time.timeIntervalSince(slot)) < 1 && $0.isTaken }
            guard let outcome = dependencies.errorPresenter.attempt({ try dependencies.doseLogging.revertTaken(taken) }) else { return }
            await afterWrite()
            await outcome.waitForReminders()
        }
    }

    /// Returns as soon as the snapshot is rewritten, not after the reminder rebuild,
    /// which takes a second or more and finishes under a background task instead.
    /// - Parameter work: the write; calls `afterWrite` once it is in the store.
    private static func run(
        _ ids: [UUID],
        work: @escaping (AppDependencies, _ afterWrite: () async -> Void) async -> Void
    ) async {
        // A button built for doses all logged meanwhile.
        guard !ids.isEmpty, let delegate = AppDelegate.shared else { return }

        // Reading `launcher` opens the store if this launch came from the widget.
        guard let dependencies = delegate.launcher.dependencies else {
            await AppDelegate.reportNotRecorded()
            return
        }

        let backgroundTask = BackgroundExecution(name: "Widget dose")
        await withCheckedContinuation { (snapshotWritten: CheckedContinuation<Void, Never>) in
            let resume = ResumeOnce(snapshotWritten)
            Task {
                await work(dependencies) {
                    await dependencies.widgetSnapshots.refresh().value
                    resume()
                }
                // Nothing written (already in that state, or the write failed): return now.
                resume()
                backgroundTask.end()
            }
        }
    }
}
