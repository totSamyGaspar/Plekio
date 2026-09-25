//
//  ReminderSyncCoordinatorTests.swift
//  PlekioTests
//
//  The coordinator is what keeps the reminders in step with course edits now
//  that no screen rebuilds them itself. Driven through an injected publisher,
//  so a test controls exactly when a change arrives.
//

import Testing
import Foundation
import Combine
@testable import Plekio

@MainActor
@Suite("ReminderSyncCoordinator Tests")
struct ReminderSyncCoordinatorTests {

    @Test("изменение курсов пересобирает напоминания, и только по активным курсам")
    func courseChangeRebuildsForActiveCoursesOnly() async {
        let db = MockDatabaseService()
        let notifications = MockNotificationService()
        let active = TreatmentCourse(name: "Активный", startDate: Date(), endDate: Date().addingTimeInterval(86400 * 5))
        let expired = TreatmentCourse(
            name: "Просроченный",
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

    @Test("без изменений координатор ничего не делает")
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

    @Test("sync() — ручной запуск, например при возврате в приложение")
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
}
