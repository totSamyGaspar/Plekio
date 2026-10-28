//
//  ShortcutDoseActions.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Foundation

/// Carries out the dose shortcuts in the app, through the same dose logging as Today.
/// Errors are thrown, not shown: Siri says them, and there may be no screen.
@MainActor
enum ShortcutDoseActions {

    static func takeDue() async throws -> DueDoses.Slot? {
        try await logDue { try $0.doseLogging.markTaken($1) }
    }

    static func skipDue() async throws -> DueDoses.Slot? {
        try await logDue { try $0.doseLogging.markSkipped($1) }
    }

    static func upcoming() throws -> DueDoses.Upcoming {
        let dependencies = try openDependencies()
        let now = dependencies.time.now
        let calendar = dependencies.time.calendar
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return DueDoses.upcoming(
            today: dependencies.database.fetchPills(for: now, preFetchedCourses: nil),
            tomorrow: dependencies.database.fetchPills(for: tomorrow, preFetchedCourses: nil),
            at: now
        )
    }

    /// Returns once the widget's snapshot is rewritten; the reminder rebuild, which
    /// takes a second or more, finishes under a background task.
    private static func logDue(
        _ command: (AppDependencies, [PillDose]) throws -> DoseLogOutcome
    ) async throws -> DueDoses.Slot? {
        let dependencies = try openDependencies()
        let pills = dependencies.database.fetchPills(for: dependencies.time.now, preFetchedCourses: nil)
        guard let slot = DueDoses.due(in: pills, at: dependencies.time.now) else { return nil }

        let outcome = try command(dependencies, slot.doses)
        await dependencies.widgetSnapshots.refresh().value

        let backgroundExecution = BackgroundExecution(name: "Shortcut dose")
        Task {
            await outcome.waitForReminders()
            backgroundExecution.end()
        }
        return slot
    }

    /// Reading `launcher` opens the store if Siri launched the app.
    private static func openDependencies() throws -> AppDependencies {
        guard let dependencies = AppDelegate.shared?.launcher.dependencies else {
            throw ShortcutError.storeUnavailable
        }
        return dependencies
    }
}
