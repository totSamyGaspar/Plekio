//
//  ReminderSyncCoordinatorTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
import Combine
@testable import Plekio

@MainActor
@Suite("ReminderSyncCoordinator Tests")
struct ReminderSyncCoordinatorTests {

    // MARK: - Sync triggers

    @Test("A course change rebuilds reminders, for active courses only")
    func courseChangeRebuildsForActiveCoursesOnly() async {
        let db = MockDatabaseService()
        let notifications = MockNotificationService()
        let active = TreatmentCourse(name: "Active", startDate: Date(), endDate: Date().addingTimeInterval(86400 * 5))
        let expired = TreatmentCourse(
            name: "Expired",
            startDate: Date().addingTimeInterval(-86400 * 10),
            endDate: Date().addingTimeInterval(-86400)
        )
        db.coursesToReturn = [active, expired]

        let changes = PassthroughSubject<Void, Never>()
        let coordinator = ReminderSyncCoordinator(
            notificationService: notifications,
            dbService: db,
            changes: changes.eraseToAnyPublisher()
        )

        changes.send()
        await coordinator.lastSync?.value

        #expect(notifications.scheduleCallCount == 1)
        #expect(notifications.didCallRemoveAllPending == true)
        #expect(notifications.scheduledCourses?.count == 1)
        #expect(notifications.scheduledCourses?.first === active)
    }

    @Test("Without changes the coordinator does nothing")
    func noChangeNoRebuild() async {
        let notifications = MockNotificationService()
        let coordinator = ReminderSyncCoordinator(
            notificationService: notifications,
            dbService: MockDatabaseService(),
            changes: PassthroughSubject<Void, Never>().eraseToAnyPublisher()
        )

        #expect(coordinator.lastSync == nil)
        #expect(notifications.scheduleCallCount == 0)
    }

    @Test("sync() runs on demand, e.g. when the app becomes active")
    func manualSyncCanBeAwaited() async {
        let notifications = MockNotificationService()
        let coordinator = ReminderSyncCoordinator(
            notificationService: notifications,
            dbService: MockDatabaseService(),
            changes: Empty<Void, Never>().eraseToAnyPublisher()
        )

        await coordinator.sync().value

        #expect(notifications.scheduleCallCount == 1)
    }

    // MARK: - Permission

    @Test("Without courses notification permission isn't requested")
    func noCoursesNoPermissionPrompt() async {
        let notifications = MockNotificationService()
        let coordinator = ReminderSyncCoordinator(
            notificationService: notifications,
            dbService: MockDatabaseService(),
            changes: Empty<Void, Never>().eraseToAnyPublisher()
        )

        await coordinator.sync().value

        #expect(notifications.requestPermissionCallCount == 0)
    }

    @Test("Once a course exists, permission is requested once")
    func firstCourseAsksForPermissionOnce() async {
        let db = MockDatabaseService()
        let notifications = MockNotificationService()
        let coordinator = ReminderSyncCoordinator(
            notificationService: notifications,
            dbService: db,
            changes: Empty<Void, Never>().eraseToAnyPublisher(),
            canRequestPermission: { true }
        )
        await coordinator.sync().value

        db.coursesToReturn = [TreatmentCourse(name: "Course", startDate: Date(), endDate: Date())]
        await coordinator.sync().value
        await coordinator.sync().value

        #expect(await waitUntil { notifications.requestPermissionCallCount == 1 })
        #expect(notifications.requestPermissionCallCount == 1)
    }
}
