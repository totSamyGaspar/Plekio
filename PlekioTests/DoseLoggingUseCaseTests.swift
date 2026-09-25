//
//  DoseLoggingUseCaseTests.swift
//  PlekioTests
//
//  The use case on its own, without a screen. What the dashboard tests check
//  through DashboardViewModel holds here directly — and so it holds for the
//  notification buttons and the push-opened sheet too, which have no view model.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DoseLoggingUseCase Tests")
struct DoseLoggingUseCaseTests {

    private func dose(at slot: Date, taken: Bool = false, skipped: Bool = false) -> PillDose {
        let status: DoseStatus = taken ? .taken(at: slot, dispensed: 1)
            : skipped ? .skipped(at: slot)
            : .pending
        return PillDose(
            medicationId: UUID(), name: "Доза", dosage: 1,
            formSystemImage: "pills.fill", time: slot, period: .morning, status: status
        )
    }

    @Test("markTaken пишет только открытые дозы, а outcome позволяет дождаться напоминаний")
    func markTakenWritesOnlyOpenDoses() async throws {
        let db = MockDatabaseService()
        let notifications = MockNotificationService()
        let slot = Date().addingTimeInterval(-30 * 60)
        let taken = dose(at: slot, taken: true)
        let open = dose(at: slot)
        db.pillsToReturn = [taken, open]
        let useCase = DoseLoggingUseCase(dbService: db, notificationService: notifications)

        let outcome = try useCase.markTaken([taken, open])

        #expect(outcome.written.map(\.medicationId) == [open.medicationId])
        #expect(db.markedTakenSlots.count == 1)

        // Awaited, not polled: this handle is what AppDelegate relies on.
        await outcome.waitForReminders()
        #expect(notifications.scheduleCallCount == 1)
        #expect(Set(notifications.clearedDeliveredIds ?? []) == Set([taken.medicationId, open.medicationId]))
    }

    @Test("когда писать нечего — ни записи, ни перепланировки")
    func nothingToWriteStartsNothing() throws {
        let db = MockDatabaseService()
        let notifications = MockNotificationService()
        let slot = Date().addingTimeInterval(-30 * 60)
        let doses = [dose(at: slot, taken: true), dose(at: slot, skipped: true)]
        db.pillsToReturn = doses
        let useCase = DoseLoggingUseCase(dbService: db, notificationService: notifications)

        let taken = try useCase.markTaken([doses[0]])
        let skipped = try useCase.markSkipped(doses)

        #expect(!taken.didWrite && taken.reminderSync == nil)
        #expect(!skipped.didWrite && skipped.reminderSync == nil)
        #expect(db.markedTakenSlots.isEmpty && db.skippedSlots.isEmpty)
    }

    @Test("revertTaken сверяется с базой, а не с переданными дозами")
    func revertTakenReadsCurrentState() async throws {
        let db = MockDatabaseService()
        let notifications = MockNotificationService()
        let slot = Date().addingTimeInterval(-30 * 60)
        let stillTaken = dose(at: slot, taken: true)
        let untickedByHand = dose(at: slot, taken: false)
        db.pillsToReturn = [stillTaken, untickedByHand]
        let useCase = DoseLoggingUseCase(dbService: db, notificationService: notifications)

        // Handed in as they were at "Log all" time — both taken.
        var staleCopy = untickedByHand
        staleCopy.status = .taken(at: slot, dispensed: 1)
        let outcome = try useCase.revertTaken([stillTaken, staleCopy])

        #expect(db.unmarkedTakenSlots.first?.medicationIds == [stillTaken.medicationId])
        await outcome.waitForReminders()
        #expect(notifications.scheduleCallCount == 1)
        // Nothing is settled by an undo, so nothing is cleared.
        #expect(notifications.clearDeliveredCallCount == 0)
    }

    @Test("openDoses находит слот с допуском в секунду и пропускает принятые")
    func openDosesMatchesSlotWithTolerance() {
        let db = MockDatabaseService()
        let slot = Date().addingTimeInterval(-30 * 60)
        let taken = dose(at: slot, taken: true)
        let open = dose(at: slot)
        let otherSlot = dose(at: slot.addingTimeInterval(3600))
        db.pillsToReturn = [taken, open, otherSlot]
        let useCase = DoseLoggingUseCase(dbService: db, notificationService: MockNotificationService())

        // The time arrives from userInfo as a Double, so it can be a hair off.
        let found = useCase.openDoses(
            medicationIds: [taken.medicationId, open.medicationId, otherSlot.medicationId],
            at: slot.addingTimeInterval(0.4)
        )

        #expect(found.map(\.medicationId) == [open.medicationId])
    }

    // MARK: - Commands and undo

    @Test("у каждой команды есть обратная, и обратная к обратной — она сама")
    func everyCommandHasAnInverse() {
        let doses = [dose(at: Date())]
        for command in [DoseCommand.take(doses), .skip(doses), .revertTake(doses), .revertSkip(doses)] {
            #expect(command.inverse != command)
            #expect(command.inverse.inverse == command)
        }
    }

    @Test("пропуск возвращает команду отмены, и она возвращает дозу в «ожидает»")
    func skipHandsBackItsUndo() throws {
        let db = MockDatabaseService()
        let slot = Date().addingTimeInterval(-30 * 60)
        let open = dose(at: slot)
        db.pillsToReturn = [open]
        let useCase = DoseLoggingUseCase(dbService: db, notificationService: MockNotificationService())

        let skipped = try useCase.markSkipped([open])
        let undo = try #require(skipped.undo)
        #expect(undo == .revertSkip(skipped.written))

        let reverted = try useCase.perform(undo)

        #expect(db.unskippedSlots.first?.medicationIds == [open.medicationId])
        #expect(db.pillsToReturn.first?.isSkipped == false)
        // And the undo can itself be undone: redo is the next command too.
        #expect(reverted.undo == .skip(reverted.written))
    }

    @Test("отмена судит по базе: доза, принятая после пропуска, так и остаётся принятой")
    func undoOfASkipLeavesALaterTakeAlone() throws {
        let db = MockDatabaseService()
        let slot = Date().addingTimeInterval(-30 * 60)
        let open = dose(at: slot)
        db.pillsToReturn = [open]
        let useCase = DoseLoggingUseCase(dbService: db, notificationService: MockNotificationService())

        let undo = try #require(try useCase.markSkipped([open]).undo)
        // The user changes their mind by hand before pressing Undo.
        _ = try useCase.markTaken([open])

        let outcome = try useCase.perform(undo)

        #expect(!outcome.didWrite)
        #expect(db.unskippedSlots.isEmpty)
        #expect(db.pillsToReturn.first?.isTaken == true)
    }

    @Test("когда писать нечего, отменять тоже нечего")
    func nothingWrittenMeansNoUndo() throws {
        let db = MockDatabaseService()
        let taken = dose(at: Date(), taken: true)
        db.pillsToReturn = [taken]
        let useCase = DoseLoggingUseCase(dbService: db, notificationService: MockNotificationService())

        #expect(try useCase.markTaken([taken]).undo == nil)
    }
}
