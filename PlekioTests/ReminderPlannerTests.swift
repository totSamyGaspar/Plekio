//
//  ReminderPlannerTests.swift
//  PlekioTests
//
//  Cancellation, regrouping and lock-screen cleanup. None of this could be
//  tested before: the rules took UNNotification values, which cannot be
//  constructed outside the system, so they only ever ran on a device. They take
//  ReminderSnapshot now, and these are the cases that have actually gone wrong.
//

import Testing
import Foundation
import UserNotifications
@testable import Plekio

@MainActor
@Suite("ReminderPlanner queue decisions")
struct ReminderPlannerTests {

    private func snapshot(
        _ identifier: String,
        ids: [UUID],
        names: [String]? = nil,
        slot: Date? = nil,
        withTrigger: Bool = true
    ) -> ReminderSnapshot {
        ReminderSnapshot(
            identifier: identifier,
            medicationIds: ids.map(\.uuidString),
            medicationNames: names ?? ids.indices.map { "Лекарство \($0)" },
            slotTime: slot?.timeIntervalSince1970,
            trigger: withTrigger
                ? UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
                : nil
        )
    }

    // MARK: - Cancelling one medication

    // A delivered notification cannot be edited, only removed. Removing any
    // notification that merely MENTIONED the id took the reminder for the other
    // medications in that slot down with it.
    @Test("с локскрина снимается только уведомление про одно это лекарство")
    func testDeliveredIsRemovedOnlyWhenItNamesNothingElse() async throws {
        let target = UUID()
        let other = UUID()

        let plan = ReminderPlanner.cancellationPlan(
            forMedication: target,
            pending: [],
            delivered: [
                snapshot("alone", ids: [target]),
                snapshot("shared", ids: [target, other]),
                snapshot("unrelated", ids: [other])
            ]
        )

        #expect(plan.deliveredToRemove == ["alone"])
    }

    // The pending half is the opposite: a queued group CAN be replaced, so
    // cancelling one medication must not silence the others sharing its time.
    @Test("групповое напоминание пересобирается без одного лекарства")
    func testPendingGroupIsRegroupedWithoutTheCancelledMedication() async throws {
        let target = UUID()
        let kept = UUID()
        let slot = testDate(2026, 6, 10, 9, 0)

        let plan = ReminderPlanner.cancellationPlan(
            forMedication: target,
            pending: [
                snapshot("group", ids: [target, kept], names: ["Ибупрофен", "Магний"], slot: slot)
            ],
            delivered: []
        )

        #expect(plan.pendingToRemove == ["group"])
        #expect(plan.regrouped.count == 1)

        let regrouped = try #require(plan.regrouped.first)
        // Same identifier, so the replacement takes the original's place.
        #expect(regrouped.identifier == "group")
        #expect(regrouped.medicationIds == [kept.uuidString])
        #expect(regrouped.medicationNames == ["Магний"])
        #expect(abs(regrouped.triggerDate.timeIntervalSince(slot)) < 1)
    }

    @Test("напоминание про одно только это лекарство просто удаляется")
    func testSoleMedicationReminderIsRemovedNotRegrouped() async throws {
        let target = UUID()

        let plan = ReminderPlanner.cancellationPlan(
            forMedication: target,
            pending: [snapshot("solo", ids: [target], slot: testDate(2026, 6, 10, 9, 0))],
            delivered: []
        )

        #expect(plan.pendingToRemove == ["solo"])
        #expect(plan.regrouped.isEmpty)
    }

    @Test("чужие напоминания не трогаются вовсе")
    func testUnrelatedRemindersAreLeftAlone() async throws {
        let plan = ReminderPlanner.cancellationPlan(
            forMedication: UUID(),
            pending: [snapshot("other", ids: [UUID()], slot: testDate(2026, 6, 10, 9, 0))],
            delivered: [snapshot("other-delivered", ids: [UUID()])]
        )

        #expect(plan.isEmpty)
    }

    // Names arrived later than ids. A request scheduled by an older version of the
    // app carries none, so there is nothing to rebuild the body text from — it can
    // only be removed, not regrouped.
    @Test("старое напоминание без имён удаляется, а не пересобирается криво")
    func testReminderWithoutNamesIsOnlyRemoved() async throws {
        let target = UUID()
        let kept = UUID()

        let plan = ReminderPlanner.cancellationPlan(
            forMedication: target,
            pending: [
                snapshot("legacy", ids: [target, kept], names: [], slot: testDate(2026, 6, 10, 9, 0))
            ],
            delivered: []
        )

        #expect(plan.pendingToRemove == ["legacy"])
        #expect(plan.regrouped.isEmpty)
    }

    // MARK: - Clearing the lock screen

    @Test("баннер снимается только когда весь слот закрыт")
    func testDeliveredClearsOnlyAFullySettledSlot() async throws {
        let first = UUID()
        let second = UUID()
        let slot = testDate(2026, 6, 10, 9, 0)
        let delivered = [snapshot("slot", ids: [first, second], slot: slot)]

        // One of the two answered for: the reminder is still valid.
        #expect(
            ReminderPlanner.deliveredToClear(
                settledMedicationIds: [first.uuidString], slot: slot, delivered: delivered
            ).isEmpty
        )

        // Both answered for.
        #expect(
            ReminderPlanner.deliveredToClear(
                settledMedicationIds: [first.uuidString, second.uuidString],
                slot: slot,
                delivered: delivered
            ) == ["slot"]
        )
    }

    @Test("баннер другого слота не снимается")
    func testDeliveredOfAnotherSlotIsLeftAlone() async throws {
        let med = UUID()
        let slot = testDate(2026, 6, 10, 9, 0)

        let toRemove = ReminderPlanner.deliveredToClear(
            settledMedicationIds: [med.uuidString],
            slot: slot,
            delivered: [snapshot("evening", ids: [med], slot: testDate(2026, 6, 10, 21, 0))]
        )

        #expect(toRemove.isEmpty)
    }

    // The slot time goes through userInfo as a Double, so a round-tripped value is
    // compared with a second of slack rather than for exact equality.
    @Test("дробная разница в доли секунды не мешает опознать слот")
    func testSlotMatchToleratesSubSecondDrift() async throws {
        let med = UUID()
        let slot = testDate(2026, 6, 10, 9, 0)

        let toRemove = ReminderPlanner.deliveredToClear(
            settledMedicationIds: [med.uuidString],
            slot: slot,
            delivered: [snapshot("slot", ids: [med], slot: slot.addingTimeInterval(0.4))]
        )

        #expect(toRemove == ["slot"])
    }

    @Test("напоминание без слота (дневник, давление) не считается дозой")
    func testReminderWithoutASlotIsNeverCleared() async throws {
        let med = UUID()

        let toRemove = ReminderPlanner.deliveredToClear(
            settledMedicationIds: [med.uuidString],
            slot: testDate(2026, 6, 10, 9, 0),
            delivered: [snapshot("diary", ids: [med], slot: nil)]
        )

        #expect(toRemove.isEmpty)
    }
}
