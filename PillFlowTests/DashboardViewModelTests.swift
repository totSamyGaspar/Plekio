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
            dosage: "1 pcs",
            formSystemImage: "pills.fill",
            time: Date(),
            period: .morning,
            isTaken: false,
            stockCount: 10,
            lowStockThreshold: 3
        )
        mockDB.pillsToReturn = [pill]

        let vm = DashboardViewModel(dbService: mockDB, notificationService: mockNotifications)

        // Act
        vm.togglePill(id: pill.id)

        // The toggle reached the DB with the right parameters.
        #expect(mockDB.toggledPillMedicationId == medId)
        #expect(mockDB.toggledPillScheduledTime == pill.time)

        // togglePill must reschedule notifications: full reset, then
        // reschedule only for courses that haven't ended yet.
        #expect(mockNotifications.didCallRemoveAllPending == true)
        #expect(mockNotifications.scheduledCourses?.count == 1)
        #expect(mockNotifications.scheduledCourses?.first === activeCourse)
    }

    @Test("morningPills/noonPills/eveningPills filter doses by period of day")
    func testPeriodFiltering() async throws {
        let mockDB = MockDatabaseService()
        let mockNotifications = MockNotificationService()

        let morning = PillDose(medicationId: UUID(), name: "Утро", dosage: "1 pcs", formSystemImage: "pills.fill", time: Date(), period: .morning, isTaken: false)
        let noon = PillDose(medicationId: UUID(), name: "День", dosage: "1 pcs", formSystemImage: "pills.fill", time: Date(), period: .noon, isTaken: false)
        let evening = PillDose(medicationId: UUID(), name: "Вечер", dosage: "1 pcs", formSystemImage: "pills.fill", time: Date(), period: .evening, isTaken: false)
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
}
