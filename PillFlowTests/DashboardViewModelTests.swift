//
//  DashboardViewModelTests.swift
//  PillFlowTests
//
//  Tests for DashboardViewModel, the app's main screen. The key test here is a
//  regression guard for a reported bug: marking a dose as taken in advance did
//  not cancel or reschedule its pending notification. Fixed by rescheduling
//  notifications inside togglePill; this test locks that behavior in.
//

import Testing
import Foundation
@testable import PillFlow

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
        #expect(mockNotifications.clearDeliveredCallCount == 1)
        #expect(mockNotifications.clearedDeliveredSlot == slot)
        #expect(mockNotifications.clearedDeliveredIds == [firstId])

        // Second logged — both doses in the slot are now taken.
        vm.togglePill(id: second.id)
        #expect(mockNotifications.clearDeliveredCallCount == 2)
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
        #expect(mockNotifications.clearDeliveredCallCount == 1)

        vm.togglePill(id: pill.id)                       // un-logged
        #expect(mockNotifications.clearDeliveredCallCount == 1)
    }
}
