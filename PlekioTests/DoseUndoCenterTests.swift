//
//  DoseUndoCenterTests.swift
//  PlekioTests
//
//  The shared undo window: what it offers, what undoing runs, and that an
//  action taken outside the dashboard reaches the dashboard's banner.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DoseUndoCenter")
struct DoseUndoCenterTests {

    private func pill(at slot: Date) -> PillDose {
        PillDose(medicationId: UUID(), name: "Ибупрофен", dosage: 1, formSystemImage: "pills.fill",
                 time: slot, period: .morning)
    }

    @Test("нечего отменять — окно не открывается")
    func nilUndoOffersNothing() {
        let db = MockDatabaseService()
        let center = DoseUndoCenter(
            doseLogging: DoseLoggingUseCase(dbService: db, notificationService: MockNotificationService()),
            errors: SpyErrorReporter(), time: SystemTime()
        )

        center.offer(.logged, undo: nil)

        #expect(center.current == nil)
    }

    @Test("отмена выполняет обратную команду и закрывает окно")
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

    @Test("«Принять» из окна пуша видно в баннере дашборда")
    func notificationActionReachesTheDashboardBanner() throws {
        // The regression this closes: the modal a notification opens is shown by
        // MainTabView, and its "Take" had no undo, though the user lands on the
        // dashboard right after.
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
