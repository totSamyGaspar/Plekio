//
//  DoseSheetActionsTests.swift
//  PlekioTests
//
//  The take-sheet's three buttons. They were wired separately in DashboardView
//  and MainTabView, with Snooze written out in both views; now one object
//  serves both, and it can be tested without either.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DoseSheetActions")
struct DoseSheetActionsTests {

    private let slot = Date().addingTimeInterval(-30 * 60)

    private func dose(taken: Bool = false) -> PillDose {
        PillDose(medicationId: UUID(), name: "Ибупрофен", dosage: 1,
                 formSystemImage: "pills.fill", time: slot, period: .morning,
                 status: taken ? .taken(at: slot, dispensed: 1) : .pending)
    }

    @MainActor
    private struct Harness {
        let db = MockDatabaseService()
        let notifications = MockNotificationService()
        let errors = SpyErrorReporter()
        let undo: DoseUndoCenter
        let actions: DoseSheetActions

        @MainActor
        init() {
            let logging = DoseLoggingUseCase(dbService: db, notificationService: notifications)
            undo = DoseUndoCenter(doseLogging: logging, errors: errors, time: SystemTime())
            actions = DoseSheetActions(doseLogging: logging, notifications: notifications, undo: undo, errors: errors)
        }
    }

    @Test("«Принять» записывает открытые дозы и предлагает отмену в общем баннере")
    func takeLogsAndOffersUndo() {
        let h = Harness()
        let open = dose()
        h.db.pillsToReturn = [open]

        h.actions.take([open])

        #expect(h.db.pillsToReturn.first?.isTaken == true)
        #expect(h.undo.current?.kind == .logged)

        // The banner undoes exactly what was written.
        #expect(h.undo.undo())
        #expect(h.db.pillsToReturn.first?.isTaken == false)
    }

    @Test("«Пропустить» записывает пропуск и тоже предлагает отмену")
    func skipRecordsAndOffersUndo() {
        let h = Harness()
        let open = dose()
        h.db.pillsToReturn = [open]

        h.actions.skip([open])

        #expect(h.db.pillsToReturn.first?.isSkipped == true)
        #expect(h.undo.current?.kind == .skipped)
    }

    @Test("если писать нечего, баннер не появляется")
    func nothingWrittenNoBanner() {
        let h = Harness()
        let taken = dose(taken: true)
        h.db.pillsToReturn = [taken]

        h.actions.take([taken])

        #expect(h.db.markedTakenSlots.isEmpty)
        #expect(h.undo.current == nil)
    }

    @Test("«Отложить» ставит повтор и ничего не пишет")
    func snoozeSchedulesOnly() async {
        let h = Harness()
        let open = dose()
        h.db.pillsToReturn = [open]

        await h.actions.snooze([open]).value

        #expect(h.notifications.snoozedMedicationIds == [open.medicationId.uuidString])
        #expect(h.db.markedTakenSlots.isEmpty)
        #expect(h.db.skippedSlots.isEmpty)
        #expect(h.undo.current == nil)
    }
}
