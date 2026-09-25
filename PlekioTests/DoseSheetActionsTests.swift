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

    // MARK: - Skipping
    //
    // Moved from DashboardViewModelTests with the dashboard's own skipDoses:
    // Skip lives only on the sheet, and the sheet's buttons are here.

    private func makeActions(_ db: MockDatabaseService,
                             _ notifications: MockNotificationService) -> (DoseSheetActions, DoseUndoCenter) {
        let logging = DoseLoggingUseCase(dbService: db, notificationService: notifications)
        let errors = SpyErrorReporter()
        let undo = DoseUndoCenter(doseLogging: logging, errors: errors, time: SystemTime())
        return (DoseSheetActions(doseLogging: logging, notifications: notifications, undo: undo, errors: errors), undo)
    }

    @Test("пропуск пишется в базу и не отменяет уведомления по лекарству")
    func testSkipRecordsTheDoseWithoutCancellingTheMedication() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let slot = Date().addingTimeInterval(-30 * 60)
        let medId = UUID()
        let pill = PillDose(
            medicationId: medId, name: "Ибупрофен", dosage: 1,
            formSystemImage: "pills.fill", time: slot, period: .morning
        )
        mockDB.pillsToReturn = [pill]

        let (actions, undo) = makeActions(mockDB, mockNotifications)

        actions.skip([pill])

        // Written down, rather than being the absence of a log.
        #expect(mockDB.skippedSlots.count == 1)
        #expect(mockDB.skippedSlots.first?.medicationIds == [medId])
        #expect(mockDB.skippedSlots.first?.scheduledTime == slot)
        #expect(mockDB.pillsToReturn.first?.isSkipped == true)

        // The whole point: the schedule is rebuilt from the database, and the
        // per-medication cancellation that used to take every future reminder
        // with it is never called.
        #expect(await waitUntil { mockNotifications.scheduleCallCount == 1 })
        #expect(mockNotifications.cancelledMedicationIds.isEmpty)

        // And the banner for the now-settled slot comes off the lock screen.
        #expect(await waitUntil { mockNotifications.clearDeliveredCallCount == 1 })
        #expect(mockNotifications.clearedDeliveredIds == [medId])
    }

    @Test("пропуск слота не трогает уже принятую в нём дозу")
    func testSkipLeavesAnAlreadyTakenDoseAlone() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let slot = Date().addingTimeInterval(-30 * 60)
        let takenId = UUID()
        let openId = UUID()
        let alreadyTaken = PillDose(
            medicationId: takenId, name: "Ибупрофен", dosage: 1,
            formSystemImage: "pills.fill", time: slot, period: .morning, status: .taken(at: Date(), dispensed: 1)
        )
        let stillOpen = PillDose(
            medicationId: openId, name: "Магний", dosage: 1,
            formSystemImage: "capsule.fill", time: slot, period: .morning
        )
        mockDB.pillsToReturn = [alreadyTaken, stillOpen]

        let (actions, undo) = makeActions(mockDB, mockNotifications)

        actions.skip([alreadyTaken, stillOpen])

        // "Skip All" must not un-take, for the same reason "Take All" must not
        // un-log — only the open dose is written.
        #expect(mockDB.skippedSlots.count == 1)
        #expect(mockDB.skippedSlots.first?.medicationIds == [openId])
        #expect(mockDB.pillsToReturn.first(where: { $0.medicationId == takenId })?.isTaken == true)
        #expect(mockDB.pillsToReturn.first(where: { $0.medicationId == takenId })?.isSkipped == false)

        // The slot is fully settled now — one taken, one skipped — so the banner
        // is cleared naming both, not just the dose that was skipped.
        #expect(await waitUntil { mockNotifications.clearDeliveredCallCount == 1 })
        #expect(Set(mockNotifications.clearedDeliveredIds ?? []) == Set([takenId, openId]))
    }

    @Test("повторный пропуск уже пропущенной дозы ничего не пишет")
    func testSkippingAnAlreadySkippedDoseIsANoOp() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        var pill = PillDose(
            medicationId: UUID(), name: "Ибупрофен", dosage: 1,
            formSystemImage: "pills.fill", time: Date().addingTimeInterval(-30 * 60),
            period: .morning
        )
        pill.status = .skipped(at: Date())
        mockDB.pillsToReturn = [pill]

        let (actions, undo) = makeActions(mockDB, mockNotifications)

        actions.skip([pill])

        #expect(mockDB.skippedSlots.isEmpty)
        #expect(mockNotifications.scheduleCallCount == 0)
    }

    @Test("пропуск можно отменить — доза снова ждёт ответа")
    func testSkipCanBeUndone() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let slot = Date().addingTimeInterval(-30 * 60)
        let pill = PillDose(
            medicationId: UUID(), name: "Ибупрофен", dosage: 1,
            formSystemImage: "pills.fill", time: slot, period: .morning
        )
        mockDB.pillsToReturn = [pill]

        let (actions, undo) = makeActions(mockDB, mockNotifications)

        actions.skip([pill])
        // A skip used to have no way back at all; now it opens the same window
        // "Log all" does.
        #expect(undo.current?.kind == .skipped)
        #expect(mockDB.pillsToReturn.first?.isSkipped == true)

        _ = undo.undo()

        #expect(mockDB.unskippedSlots.first?.medicationIds == [pill.medicationId])
        #expect(mockDB.pillsToReturn.first?.isSkipped == false)
        #expect(undo.current == nil)
    }
}
