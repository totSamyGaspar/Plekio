//
//  DashboardViewModelTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 22.08.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DashboardViewModel Tests")
struct DashboardViewModelTests {

    // MARK: - Toggling and periods

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

        let morning = PillDose(medicationId: UUID(), name: "Утро", dosage: 1, formSystemImage: "pills.fill", time: Date(), period: .morning)
        let noon = PillDose(medicationId: UUID(), name: "День", dosage: 1, formSystemImage: "pills.fill", time: Date(), period: .noon)
        let evening = PillDose(medicationId: UUID(), name: "Вечер", dosage: 1, formSystemImage: "pills.fill", time: Date(), period: .evening)
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

        // Three perfect days out of seven must read as 100%, not 3/7.
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        for offset in 0...2 {
            let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday)!
            mockDB.pillsByDay[day] = [
                PillDose(medicationId: UUID(), name: "Аспирин", dosage: 1, formSystemImage: "pills.fill", time: day.addingTimeInterval(9 * 3600), period: .morning, status: .taken(at: Date(), dispensed: 1)),
                PillDose(medicationId: UUID(), name: "Магний", dosage: 1, formSystemImage: "capsule.fill", time: day.addingTimeInterval(20 * 3600), period: .evening, status: .taken(at: Date(), dispensed: 1)),
            ]
        }

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        await vm.weeklyLoad?.value
        #expect(vm.recentAverage == 100)
        #expect(vm.weeklyPercentages.count == 7)
        #expect(vm.weeklyDays.count == 7)
    }

    @Test("без назначений вообще недельное среднее равно нулю, а не NaN")
    func testRecentAverageWithNoDosesAtAll() async throws {
        let mockDB = MockDatabaseService()
        mockDB.pillsToReturn = []

        let vm = DashboardViewModel(dbService: mockDB, notificationService: MockNotificationService())

        await vm.weeklyLoad?.value
        #expect(vm.recentAverage == 0)
        #expect(vm.weeklyPercentages == Array(repeating: 0.0, count: 7))
    }

    // MARK: - Back-dated logging and delivered notifications

    @Test("отметка дозы просит убрать показанное уведомление для её слота")
    func testTogglingLoggedDoseClearsDeliveredNotification() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        // Two medications share one slot's reminder, so the logged ids are reported.
        let slot = Date().addingTimeInterval(-2 * 3600)
        let firstId = UUID()
        let secondId = UUID()
        let first = PillDose(medicationId: firstId, name: "Ибупрофен", dosage: 1, formSystemImage: "pills.fill", time: slot, period: .morning)
        let second = PillDose(medicationId: secondId, name: "Магний", dosage: 1, formSystemImage: "capsule.fill", time: slot, period: .morning)
        mockDB.pillsToReturn = [first, second]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.togglePill(id: first.id)
        #expect(await waitUntil { mockNotifications.clearDeliveredCallCount == 1 })
        #expect(mockNotifications.clearedDeliveredSlot == slot)
        #expect(mockNotifications.clearedDeliveredIds == [firstId])

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
            period: .morning
        )
        mockDB.pillsToReturn = [pill]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.togglePill(id: pill.id)
        #expect(await waitUntil { mockNotifications.clearDeliveredCallCount == 1 })

        vm.togglePill(id: pill.id)
        // Wait for the second rebuild so a missing cleanup is final, not just pending.
        #expect(await waitUntil { mockNotifications.scheduleCallCount == 2 })
        #expect(mockNotifications.clearDeliveredCallCount == 1)
    }

    // MARK: - Bulk logging a slot

    @Test("логирование слота не снимает отметку с уже принятой дозы")
    func testLogDosesLeavesAlreadyTakenDoseAlone() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let slot = Date().addingTimeInterval(-30 * 60)
        let takenId = UUID()
        let pendingId = UUID()
        let alreadyTaken = PillDose(
            medicationId: takenId, name: "Ибупрофен", dosage: 1,
            formSystemImage: "pills.fill", time: slot, period: .morning, status: .taken(at: Date(), dispensed: 1)
        )
        let stillPending = PillDose(
            medicationId: pendingId, name: "Магний", dosage: 1,
            formSystemImage: "capsule.fill", time: slot, period: .morning
        )
        mockDB.pillsToReturn = [alreadyTaken, stillPending]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.logDoses([alreadyTaken, stillPending])

        #expect(mockDB.markedTakenSlots.count == 1)
        #expect(mockDB.markedTakenSlots.first?.medicationIds == [pendingId])
        // Toggling would un-log the already taken dose.
        #expect(mockDB.toggleCalls.isEmpty)

        #expect(vm.morningPills.count == 2)
        #expect(vm.morningPills.allSatisfy { $0.isTaken })

        // Undo offers back only the dose this action wrote.
        #expect(vm.undoableAction?.doses.map(\.medicationId) == [pendingId])
    }

    @Test("логирование слота — одна транзакция и одна перепланировка")
    func testLogDosesWritesTheWholeSlotInOneTransaction() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let slot = Date().addingTimeInterval(-30 * 60)
        let pills = (0..<3).map { index in
            PillDose(
                medicationId: UUID(), name: "Доза \(index)", dosage: 1,
                formSystemImage: "pills.fill", time: slot, period: .noon
            )
        }
        mockDB.pillsToReturn = pills

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.logDoses(pills)

        #expect(mockDB.markedTakenSlots.count == 1)
        #expect(Set(mockDB.markedTakenSlots.first?.medicationIds ?? []) == Set(pills.map(\.medicationId)))
        #expect(mockDB.toggleCalls.isEmpty)

        // Cleanup runs after the rebuild in the same task, so the count below is final.
        #expect(await waitUntil { mockNotifications.clearDeliveredCallCount == 1 })
        #expect(Set(mockNotifications.clearedDeliveredIds ?? []) == Set(pills.map(\.medicationId)))

        #expect(mockNotifications.scheduleCallCount == 1)
    }

    @Test("подтверждённая просроченная доза всё равно логируется")
    func testLogDosesWritesADoseThatWentMissed() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        // Past the one-hour grace period: a confirmed dose is logged even if missed.
        let slot = Date().addingTimeInterval(-3 * 3600)
        let pill = PillDose(
            medicationId: UUID(), name: "Ибупрофен", dosage: 1,
            formSystemImage: "pills.fill", time: slot, period: .morning
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
                formSystemImage: "pills.fill", time: slot, period: .evening, status: .taken(at: Date(), dispensed: 1)
            )
        }
        mockDB.pillsToReturn = pills

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.logDoses(pills)

        #expect(mockDB.markedTakenSlots.isEmpty)
        #expect(mockNotifications.scheduleCallCount == 0)
        #expect(vm.undoableAction == nil)
    }

    // MARK: - Undo

    @Test("отмена массового логирования — тоже одна транзакция, и только по принятым")
    func testUndoBulkLogRevertsTheSlotInOneTransaction() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let slot = Date().addingTimeInterval(-30 * 60)
        let pills = (0..<3).map { index in
            PillDose(
                medicationId: UUID(), name: "Доза \(index)", dosage: 1,
                formSystemImage: "pills.fill", time: slot, period: .morning
            )
        }
        mockDB.pillsToReturn = pills

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        vm.logDoses(pills)
        #expect(vm.undoableAction?.count == 3)

        vm.togglePill(id: pills[0].id)
        #expect(vm.morningPills.first(where: { $0.medicationId == pills[0].medicationId })?.isTaken == false)

        vm.undoLastAction()

        // Only the doses still logged are reverted; reverting the unticked one would log it.
        #expect(mockDB.unmarkedTakenSlots.count == 1)
        #expect(
            Set(mockDB.unmarkedTakenSlots.first?.medicationIds ?? [])
            == Set([pills[1].medicationId, pills[2].medicationId])
        )
        #expect(vm.morningPills.allSatisfy { !$0.isTaken })
        #expect(vm.undoableAction == nil)
    }

    @Test("одиночная галочка баннер отмены не открывает")
    func testSingleToggleOpensNoUndoWindow() async throws {
        let mockDB = MockDatabaseService()
        let pill = PillDose(
            medicationId: UUID(), name: "Ибупрофен", dosage: 1,
            formSystemImage: "pills.fill", time: Date(), period: .morning
        )
        mockDB.pillsToReturn = [pill]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: MockNotificationService())
        vm.togglePill(id: pill.id)

        #expect(vm.undoableAction == nil)
    }

    // MARK: - Card menu and empty state

    @Test("пропуск из меню карточки пишет пропуск и предлагает отмену")
    func testSkipDoseOffersUndo() async throws {
        let mockDB = MockDatabaseService()
        let pill = PillDose(medicationId: UUID(), name: "Ибупрофен", dosage: 1,
                            formSystemImage: "pills.fill", time: Date(), period: .morning)
        mockDB.pillsToReturn = [pill]
        let vm = DashboardViewModel(dbService: mockDB, notificationService: MockNotificationService())

        vm.skipDose(id: pill.id)

        #expect(mockDB.skippedSlots.first?.medicationIds == [pill.medicationId])
        #expect(vm.undoableAction?.kind == .skipped)
        #expect(vm.morningPills.first?.isSkipped == true)
    }

    @Test("hasCourses следит за появлением первого курса")
    func testHasCoursesFollowsCourseWrites() async throws {
        let mockDB = MockDatabaseService()
        let vm = DashboardViewModel(dbService: mockDB, notificationService: MockNotificationService())
        #expect(vm.hasCourses == false)

        mockDB.coursesToReturn = [TreatmentCourse(name: "Курс", startDate: Date(), endDate: Date())]
        mockDB.changes.send([.courses])

        #expect(vm.hasCourses == true)
    }
}
