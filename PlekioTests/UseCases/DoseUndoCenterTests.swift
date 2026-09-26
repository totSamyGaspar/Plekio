//
//  DoseUndoCenterTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DoseUndoCenter")
struct DoseUndoCenterTests {

    // MARK: - Helpers

    private func pill(at slot: Date) -> PillDose {
        PillDose(medicationId: UUID(), name: "Ibuprofen", dosage: 1, formSystemImage: "pills.fill",
                 time: slot, period: .morning)
    }

    // MARK: - Offering and undoing

    @Test("Nothing to undo, no window opens")
    func nilUndoOffersNothing() {
        let db = MockDatabaseService()
        let center = DoseUndoCenter(
            doseLogging: DoseLoggingUseCase(dbService: db, notificationService: MockNotificationService()),
            errors: SpyErrorReporter(), time: SystemTime()
        )

        center.offer(.logged, undo: nil)

        #expect(center.current == nil)
    }

    @Test("Undo runs the inverse command and closes the window")
    func undoRunsTheInverseAndCloses() throws {
        let db = MockDatabaseService()
        let slot = Date().addingTimeInterval(-30 * 60)
        db.pillsToReturn = [pill(at: slot)]
        let doseLogging = DoseLoggingUseCase(dbService: db, notificationService: MockNotificationService())
        let center = DoseUndoCenter(doseLogging: doseLogging, errors: SpyErrorReporter(), time: SystemTime())

        let outcome = try doseLogging.markTaken(db.pillsToReturn)
        center.offer(.logged, undo: outcome.undo)
        #expect(center.current?.kind == .logged)

        #expect(center.undo())
        #expect(db.unmarkedTakenSlots.count == 1)
        #expect(center.current == nil)
    }

    // MARK: - Dashboard banner

    @Test("Take from the reminder sheet shows in the dashboard's banner")
    func notificationActionReachesTheDashboardBanner() throws {
        // The notification modal lives in MainTabView, but its undo must reach the dashboard.
        let db = MockDatabaseService()
        let slot = Date().addingTimeInterval(-30 * 60)
        db.pillsToReturn = [pill(at: slot)]
        let doseLogging = DoseLoggingUseCase(dbService: db, notificationService: MockNotificationService())
        let center = DoseUndoCenter(doseLogging: doseLogging, errors: SpyErrorReporter(), time: SystemTime())
        let dashboard = DashboardViewModel(
            dbService: db, doseLogging: doseLogging, errors: SpyErrorReporter(), undoCenter: center
        )

        // What MainTabView does for the notification modal.
        let outcome = try doseLogging.markTaken(db.pillsToReturn)
        center.offer(.logged, undo: outcome.undo)

        #expect(dashboard.undoableAction?.count == 1)

        dashboard.undoLastAction()
        #expect(db.pillsToReturn.allSatisfy { !$0.isTaken })
    }
}
