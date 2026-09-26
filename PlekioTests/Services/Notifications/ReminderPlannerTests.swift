//
//  ReminderPlannerTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Testing
import Foundation
import UserNotifications
@testable import Plekio

@MainActor
@Suite("ReminderPlanner queue decisions")
struct ReminderPlannerTests {

    // MARK: - Helpers

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
            medicationNames: names ?? ids.indices.map { "Medication \($0)" },
            slotTime: slot?.timeIntervalSince1970,
            trigger: withTrigger
                ? UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
                : nil
        )
    }

    // MARK: - Cancelling one medication

    // Delivered notifications can't be edited, so one naming other medications must stay.
    @Test("Only this medication's notification is removed from the lock screen")
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

    // A pending group can be replaced, so the others sharing its time stay scheduled.
    @Test("A group reminder is rebuilt without one medication")
    func testPendingGroupIsRegroupedWithoutTheCancelledMedication() async throws {
        let target = UUID()
        let kept = UUID()
        let slot = testDate(2026, 6, 10, 9, 0)

        let plan = ReminderPlanner.cancellationPlan(
            forMedication: target,
            pending: [
                snapshot("group", ids: [target, kept], names: ["Ibuprofen", "Magnesium"], slot: slot)
            ],
            delivered: []
        )

        #expect(plan.pendingToRemove == ["group"])
        #expect(plan.regrouped.count == 1)

        let regrouped = try #require(plan.regrouped.first)
        // Same identifier, so the replacement takes the original's place.
        #expect(regrouped.identifier == "group")
        #expect(regrouped.medicationIds == [kept.uuidString])
        #expect(regrouped.medicationNames == ["Magnesium"])
        #expect(abs(regrouped.triggerDate.timeIntervalSince(slot)) < 1)
    }

    @Test("A reminder for this medication alone is simply removed")
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

    @Test("Other reminders aren't touched at all")
    func testUnrelatedRemindersAreLeftAlone() async throws {
        let plan = ReminderPlanner.cancellationPlan(
            forMedication: UUID(),
            pending: [snapshot("other", ids: [UUID()], slot: testDate(2026, 6, 10, 9, 0))],
            delivered: [snapshot("other-delivered", ids: [UUID()])]
        )

        #expect(plan.isEmpty)
    }

    // Requests without names can't have their body rebuilt, so they are only removed.
    @Test("An old reminder without names is removed rather than rebuilt wrong")
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

    @Test("The banner is removed only once the whole slot is settled")
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

        #expect(
            ReminderPlanner.deliveredToClear(
                settledMedicationIds: [first.uuidString, second.uuidString],
                slot: slot,
                delivered: delivered
            ) == ["slot"]
        )
    }

    @Test("Another slot's banner stays")
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

    // Slot time round-trips through userInfo as a Double, hence the 1 s tolerance.
    @Test("A sub-second difference doesn't prevent matching the slot")
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

    @Test("A reminder without a slot (diary, blood pressure) isn't a dose")
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
