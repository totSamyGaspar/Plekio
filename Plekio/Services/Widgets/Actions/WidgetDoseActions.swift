//
//  WidgetDoseActions.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import UIKit
import os

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

    /// Returns as soon as the snapshot is rewritten (`publishNow`, no history read),
    /// before the reminder rebuild and the full refresh: WidgetKit keeps the tapped
    /// check dimmed until then. Both finish under a background task instead.
    ///
    /// `afterWrite` doesn't await anything: the reminder rebuild is already queued on
    /// the main actor by the write, and a suspension here would let it run first.
    /// - Parameter work: the write; calls `afterWrite` once it is in the store.
    private static func run(
        _ ids: [UUID],
        work: @escaping (AppDependencies, _ afterWrite: () async -> Void) async -> Void
    ) async {
        let started = ContinuousClock.now
        AppLog.widget.debug("Dose button: started, \(ids.count) dose(s)")

        // A button built for doses all logged meanwhile.
        guard !ids.isEmpty, let delegate = AppDelegate.shared else {
            AppLog.widget.error("Dose button: no doses or no AppDelegate")
            return
        }

        // Reading `launcher` opens the store if this launch came from the widget.
        guard let dependencies = delegate.launcher.dependencies else {
            AppLog.widget.error("Dose button: store not open")
            await AppDelegate.reportNotRecorded()
            return
        }
        AppLog.widget.debug("Dose button: store open, \(ms(since: started)) ms")

        let backgroundTask = BackgroundExecution(name: "Widget dose")
        await withCheckedContinuation { (snapshotWritten: CheckedContinuation<Void, Never>) in
            let resume = ResumeOnce(snapshotWritten)
            Task {
                await work(dependencies) {
                    AppLog.widget.debug("Dose button: written, \(ms(since: started)) ms")
                    dependencies.widgetSnapshots.publishNow()
                    AppLog.widget.debug("Dose button: snapshot published, answering, \(ms(since: started)) ms")
                    resume()
                }
                AppLog.widget.debug("Dose button: reminders rebuilt, \(ms(since: started)) ms")
                // Nothing written (already in that state, or the write failed): return now.
                resume()
                // The streak from the history, before iOS may suspend the app. Usually
                // the same as publishNow's, and then nothing is rewritten or reloaded.
                await dependencies.widgetSnapshots.refresh().value
                AppLog.widget.debug("Dose button: full refresh done, \(ms(since: started)) ms")
                backgroundTask.end()
            }
        }
    }

    private static func ms(since start: ContinuousClock.Instant) -> Int {
        Int((start.duration(to: .now) / .milliseconds(1)).rounded())
    }
}
