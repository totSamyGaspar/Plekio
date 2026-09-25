//
//  DashboardViewModelTests.swift
//  PlekioTests
//
//  Tests for DashboardViewModel, the app's main screen. The key test here is a
//  regression guard for a reported bug: marking a dose as taken in advance did
//  not cancel or reschedule its pending notification. Fixed by rescheduling
//  notifications inside togglePill; this test locks that behavior in.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DashboardViewModel Tests")
struct DashboardViewModelTests {

    @Test("togglePill hits the DB and reschedules pushes only for active courses")
    func testTogglePillReschedulesWithActiveCoursesOnly() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let activeCourse = TreatmentCourse(
            name: "Активный",
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date().addingTimeInterval(86400 * 5)
        )
        let expiredCourse = TreatmentCourse(
            name: "Просроченный",
            startDate: Date().addingTimeInterval(-86400 * 30),
            endDate: Date().addingTimeInterval(-86400)
        )
        mockDB.coursesToReturn = [activeCourse, expiredCourse]

        let medId = UUID()
        let pill = PillDose(
            medicationId: medId,
            name: "Ибупрофен",
            dosage: 1,
            formSystemImage: "pills.fill",
            time: Date(),
            period: .morning,
            isTaken: false,
            stockCount: 10,
            lowStockThreshold: 3
        )
        mockDB.pillsToReturn = [pill]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.togglePill(id: pill.id)

        #expect(mockDB.toggledPillMedicationId == medId)
        #expect(mockDB.toggledPillScheduledTime == pill.time)

        #expect(await waitUntil { mockNotifications.scheduleCallCount == 1 })
        #expect(mockNotifications.didCallRemoveAllPending == true)
        #expect(mockNotifications.scheduledCourses?.count == 1)
        #expect(mockNotifications.scheduledCourses?.first === activeCourse)
    }

    @Test("morningPills/noonPills/eveningPills filter doses by period of day")
    func testPeriodFiltering() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let morning = PillDose(medicationId: UUID(), name: "Утро", dosage: 1, formSystemImage: "pills.fill", time: Date(), period: .morning, isTaken: false)
        let noon = PillDose(medicationId: UUID(), name: "День", dosage: 1, formSystemImage: "pills.fill", time: Date(), period: .noon, isTaken: false)
        let evening = PillDose(medicationId: UUID(), name: "Вечер", dosage: 1, formSystemImage: "pills.fill", time: Date(), period: .evening, isTaken: false)
        mockDB.pillsToReturn = [morning, noon, evening]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        #expect(vm.morningPills.map(\.name) == ["Утро"])
        #expect(vm.noonPills.map(\.name) == ["День"])
        #expect(vm.eveningPills.map(\.name) == ["Вечер"])
        #expect(vm.isEmpty == false)
    }

    @Test("isEmpty == true when there are no doses on the selected day")
    func testIsEmptyWhenNoPills() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()
        mockDB.pillsToReturn = []

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        #expect(vm.isEmpty == true)
    }

    // MARK: - Weekly statistics

    @Test("недельное среднее считается по дням с назначениями, а не всегда по семи")
    func testRecentAverageIgnoresDaysWithoutDoses() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        // A course started three days ago and followed perfectly. The sum used to be
        // divided by 7 regardless, which showed up as 43%.
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        for offset in 0...2 {
            let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday)!
            mockDB.pillsByDay[day] = [
                PillDose(medicationId: UUID(), name: "Аспирин", dosage: 1, formSystemImage: "pills.fill", time: day.addingTimeInterval(9 * 3600), period: .morning, isTaken: true),
                PillDose(medicationId: UUID(), name: "Магний", dosage: 1, formSystemImage: "capsule.fill", time: day.addingTimeInterval(20 * 3600), period: .evening, isTaken: true),
            ]
        }

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        #expect(vm.recentAverage == 100)
        #expect(vm.weeklyPercentages.count == 7)
        #expect(vm.weeklyDays.count == 7)
    }

    @Test("без назначений вообще недельное среднее равно нулю, а не NaN")
    func testRecentAverageWithNoDosesAtAll() async throws {
        let mockDB = MockDatabaseService()
        mockDB.pillsToReturn = []

        let vm = DashboardViewModel(dbService: mockDB, notificationService: MockNotificationService())

        #expect(vm.recentAverage == 0)
        #expect(vm.weeklyPercentages == Array(repeating: 0.0, count: 7))
    }

    // MARK: - Back-dated logging and delivered notifications

    @Test("отметка дозы просит убрать показанное уведомление для её слота")
    func testTogglingLoggedDoseClearsDeliveredNotification() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        // Two medications in one slot share a single reminder, so the view model has
        // to report which of them are already logged.
        let slot = Date().addingTimeInterval(-2 * 3600)
        let firstId = UUID()
        let secondId = UUID()
        let first = PillDose(medicationId: firstId, name: "Ибупрофен", dosage: 1, formSystemImage: "pills.fill", time: slot, period: .morning, isTaken: false)
        let second = PillDose(medicationId: secondId, name: "Магний", dosage: 1, formSystemImage: "capsule.fill", time: slot, period: .morning, isTaken: false)
        mockDB.pillsToReturn = [first, second]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        // First medication logged — the slot is only half closed.
        vm.togglePill(id: first.id)
        #expect(await waitUntil { mockNotifications.clearDeliveredCallCount == 1 })
        #expect(mockNotifications.clearedDeliveredSlot == slot)
        #expect(mockNotifications.clearedDeliveredIds == [firstId])

        // Second logged — both doses in the slot are now taken.
        vm.togglePill(id: second.id)
        #expect(await waitUntil { mockNotifications.clearDeliveredCallCount == 2 })
        #expect(Set(mockNotifications.clearedDeliveredIds ?? []) == Set([firstId, secondId]))
    }

    @Test("снятие отметки уведомления не трогает")
    func testUntogglingDoesNotClearDelivered() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let pill = PillDose(
            medicationId: UUID(), name: "Ибупрофен", dosage: 1,
            formSystemImage: "pills.fill", time: Date().addingTimeInterval(-2 * 3600),
            period: .morning, isTaken: false
        )
        mockDB.pillsToReturn = [pill]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.togglePill(id: pill.id)                       // logged
        #expect(await waitUntil { mockNotifications.clearDeliveredCallCount == 1 })

        vm.togglePill(id: pill.id)                       // un-logged
        // Waits for the second rebuild, so this is "the cleanup did not happen",
        // not "the cleanup has not happened yet".
        #expect(await waitUntil { mockNotifications.scheduleCallCount == 2 })
        #expect(mockNotifications.clearDeliveredCallCount == 1)
    }

    // MARK: - Bulk logging a slot
    //
    // Regression guard. The "take all" sheet used to call togglePill for every dose
    // in the slot, so a dose the user had already ticked off was toggled a second
    // time and silently un-logged. The slot is logged through logDoses now, which
    // writes only what is still pending.

    @Test("логирование слота не снимает отметку с уже принятой дозы")
    func testLogDosesLeavesAlreadyTakenDoseAlone() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let slot = Date().addingTimeInterval(-30 * 60)
        let takenId = UUID()
        let pendingId = UUID()
        let alreadyTaken = PillDose(
            medicationId: takenId, name: "Ибупрофен", dosage: 1,
            formSystemImage: "pills.fill", time: slot, period: .morning, isTaken: true
        )
        let stillPending = PillDose(
            medicationId: pendingId, name: "Магний", dosage: 1,
            formSystemImage: "capsule.fill", time: slot, period: .morning, isTaken: false
        )
        mockDB.pillsToReturn = [alreadyTaken, stillPending]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.logDoses([alreadyTaken, stillPending])

        // One write for the slot, naming only the dose that was still open.
        #expect(mockDB.markedTakenSlots.count == 1)
        #expect(mockDB.markedTakenSlots.first?.medicationIds == [pendingId])
        // And not through the toggle, which is what used to un-log the other one.
        #expect(mockDB.toggleCalls.isEmpty)

        // And the slot reads as fully taken afterwards, rather than having swapped
        // which of the two is logged.
        #expect(vm.morningPills.count == 2)
        #expect(vm.morningPills.allSatisfy { $0.isTaken })

        // The undo banner offers back only the dose this action actually wrote.
        #expect(vm.undoableBulkLog?.doses.map(\.medicationId) == [pendingId])
    }

    @Test("логирование слота — одна транзакция и одна перепланировка")
    func testLogDosesWritesTheWholeSlotInOneTransaction() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let slot = Date().addingTimeInterval(-30 * 60)
        let pills = (0..<3).map { index in
            PillDose(
                medicationId: UUID(), name: "Доза \(index)", dosage: 1,
                formSystemImage: "pills.fill", time: slot, period: .noon, isTaken: false
            )
        }
        mockDB.pillsToReturn = pills

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.logDoses(pills)

        // Three doses in one slot: one write, one commit, one change event — where
        // three togglePill calls meant three of each.
        #expect(mockDB.markedTakenSlots.count == 1)
        #expect(Set(mockDB.markedTakenSlots.first?.medicationIds ?? []) == Set(pills.map(\.medicationId)))
        #expect(mockDB.toggleCalls.isEmpty)

        // Waits on the cleanup, which runs after the rebuild in the same task, so
        // the count below is "the rebuild ran once", not "has only run once so far".
        #expect(await waitUntil { mockNotifications.clearDeliveredCallCount == 1 })
        #expect(Set(mockNotifications.clearedDeliveredIds ?? []) == Set(pills.map(\.medicationId)))

        // One rebuild for the whole slot, not one per dose: three toggles used to
        // mean three racing rescheduleAll passes.
        #expect(mockNotifications.scheduleCallCount == 1)
    }

    @Test("подтверждённая просроченная доза всё равно логируется")
    func testLogDosesWritesADoseThatWentMissed() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        // Past the one-hour grace period, so isMissed is true. The sheet can be open
        // across that line: it is confirmation that matters, not punctuality.
        let slot = Date().addingTimeInterval(-3 * 3600)
        let pill = PillDose(
            medicationId: UUID(), name: "Ибупрофен", dosage: 1,
            formSystemImage: "pills.fill", time: slot, period: .morning, isTaken: false
        )
        #expect(pill.isMissed)
        mockDB.pillsToReturn = [pill]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.logDoses([pill])

        #expect(mockDB.markedTakenSlots.count == 1)
        #expect(vm.morningPills.first?.isTaken == true)
    }

    @Test("полностью принятый слот не пишет ничего")
    func testLogDosesOnFullyTakenSlotIsANoOp() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let slot = Date().addingTimeInterval(-30 * 60)
        let pills = (0..<2).map { index in
            PillDose(
                medicationId: UUID(), name: "Доза \(index)", dosage: 1,
                formSystemImage: "pills.fill", time: slot, period: .evening, isTaken: true
            )
        }
        mockDB.pillsToReturn = pills

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.logDoses(pills)

        #expect(mockDB.markedTakenSlots.isEmpty)
        #expect(mockNotifications.scheduleCallCount == 0)
        // Nothing was written, so there is nothing to offer back.
        #expect(vm.undoableBulkLog == nil)
    }

    // MARK: - Skipping a dose

    @Test("пропуск пишется в базу и не отменяет уведомления по лекарству")
    func testSkipRecordsTheDoseWithoutCancellingTheMedication() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let slot = Date().addingTimeInterval(-30 * 60)
        let medId = UUID()
        let pill = PillDose(
            medicationId: medId, name: "Ибупрофен", dosage: 1,
            formSystemImage: "pills.fill", time: slot, period: .morning, isTaken: false
        )
        mockDB.pillsToReturn = [pill]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.skipDoses([pill])

        // Written down, rather than being the absence of a log.
        #expect(mockDB.skippedSlots.count == 1)
        #expect(mockDB.skippedSlots.first?.medicationIds == [medId])
        #expect(mockDB.skippedSlots.first?.scheduledTime == slot)
        #expect(vm.morningPills.first?.isSkipped == true)

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
            formSystemImage: "pills.fill", time: slot, period: .morning, isTaken: true
        )
        let stillOpen = PillDose(
            medicationId: openId, name: "Магний", dosage: 1,
            formSystemImage: "capsule.fill", time: slot, period: .morning, isTaken: false
        )
        mockDB.pillsToReturn = [alreadyTaken, stillOpen]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.skipDoses([alreadyTaken, stillOpen])

        // "Skip All" must not un-take, for the same reason "Take All" must not
        // un-log — only the open dose is written.
        #expect(mockDB.skippedSlots.count == 1)
        #expect(mockDB.skippedSlots.first?.medicationIds == [openId])
        #expect(vm.morningPills.first(where: { $0.medicationId == takenId })?.isTaken == true)
        #expect(vm.morningPills.first(where: { $0.medicationId == takenId })?.isSkipped == false)

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
            period: .morning, isTaken: false
        )
        pill.isSkipped = true
        mockDB.pillsToReturn = [pill]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.skipDoses([pill])

        #expect(mockDB.skippedSlots.isEmpty)
        #expect(mockNotifications.scheduleCallCount == 0)
    }

    @Test("отмена массового логирования — тоже одна транзакция, и только по принятым")
    func testUndoBulkLogRevertsTheSlotInOneTransaction() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let slot = Date().addingTimeInterval(-30 * 60)
        let pills = (0..<3).map { index in
            PillDose(
                medicationId: UUID(), name: "Доза \(index)", dosage: 1,
                formSystemImage: "pills.fill", time: slot, period: .morning, isTaken: false
            )
        }
        mockDB.pillsToReturn = pills

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.logDoses(pills)
        #expect(vm.undoableBulkLog?.count == 3)

        // The user unticks one by hand before using the banner.
        vm.togglePill(id: pills[0].id)
        #expect(vm.morningPills.first(where: { $0.medicationId == pills[0].medicationId })?.isTaken == false)

        vm.undoBulkLog()

        // One reversal for the slot, and it names only the two doses still logged:
        // reverting the hand-unticked one would log it rather than undo it.
        #expect(mockDB.unmarkedTakenSlots.count == 1)
        #expect(
            Set(mockDB.unmarkedTakenSlots.first?.medicationIds ?? [])
            == Set([pills[1].medicationId, pills[2].medicationId])
        )
        #expect(vm.morningPills.allSatisfy { !$0.isTaken })
        #expect(vm.undoableBulkLog == nil)
    }
}
