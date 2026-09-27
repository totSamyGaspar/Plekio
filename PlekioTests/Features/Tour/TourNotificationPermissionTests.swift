import Combine
import Foundation
import Testing
@testable import Plekio

@MainActor
@Suite("Notification permission after the tour")
struct TourNotificationPermissionTests {
    @MainActor
    private final class Harness {
        let suite = "PlekioTests.TourPermission.\(UUID().uuidString)"
        let settings: SettingsStore
        let db = MockDatabaseService()
        let notifications = MockNotificationService()
        let changes = PassthroughSubject<Void, Never>()
        let coordinator: ReminderSyncCoordinator
        let tour: TourCoordinator

        init() {
            let settings = SettingsStore(defaults: UserDefaults(suiteName: suite)!)
            self.settings = settings
            let coordinator = ReminderSyncCoordinator(
                notificationService: notifications, dbService: db,
                changes: changes.eraseToAnyPublisher(),
                canRequestPermission: { settings.hasCompletedTour }
            )
            self.coordinator = coordinator
            tour = TourCoordinator(settings: settings, router: AppRouter()) { coordinator.sync() }
        }

        func createCourse() {
            db.coursesToReturn = [TreatmentCourse(name: "Course", startDate: Date(), endDate: Date())]
            changes.send()
            tour.courseCreated()
        }

        func settle() async {
            await coordinator.lastPermissionRequest?.value
            await coordinator.lastSync?.value
        }

        deinit { UserDefaults().removePersistentDomain(forName: suite) }
    }

    @Test("Creating a course during the tour waits for its last step to finish")
    func permissionWaitsForTourCompletion() async {
        let h = Harness()
        h.tour.startIfNeeded(hasCourses: false)
        h.tour.next()
        h.createCourse()
        await h.settle()
        #expect(h.tour.step == .logDose)
        #expect(h.notifications.requestPermissionCallCount == 0)

        h.tour.next()
        await h.settle()
        #expect(h.notifications.requestPermissionCallCount == 1)
    }

    @Test("Skipping the tour after course creation requests permission")
    func skipAfterCourseCreationAsks() async {
        let h = Harness()
        h.tour.startIfNeeded(hasCourses: false)
        h.tour.next()
        h.createCourse()
        h.tour.skip()
        await h.settle()
        #expect(h.notifications.requestPermissionCallCount == 1)
    }

    @Test("Skipping without a course waits until one is created")
    func skipBeforeCourseCreationWaits() async {
        let h = Harness()
        h.tour.startIfNeeded(hasCourses: false)
        h.tour.skip()
        await h.settle()
        #expect(h.notifications.requestPermissionCallCount == 0)

        h.createCourse()
        await h.settle()
        #expect(h.notifications.requestPermissionCallCount == 1)
    }

    @Test("Returning to the app during the tour does not request permission")
    func activationDuringTourDoesNotAsk() async {
        let h = Harness()
        h.tour.startIfNeeded(hasCourses: false)
        h.tour.next()
        h.createCourse()
        await h.coordinator.sync().value
        await h.settle()
        #expect(h.notifications.requestPermissionCallCount == 0)
    }

    @Test("Existing courses request permission once the tour is marked finished")
    func existingUserAsksAfterTourDecision() async {
        let h = Harness()
        h.createCourse()
        await h.settle()
        #expect(h.notifications.requestPermissionCallCount == 0)

        h.tour.startIfNeeded(hasCourses: true)
        await h.settle()
        #expect(h.notifications.requestPermissionCallCount == 1)
    }

    @Test("A declined request isn't repeated on later course changes or activations")
    func denialDoesNotRepeat() async {
        let h = Harness()
        h.notifications.permissionGranted = false
        h.settings.hasCompletedTour = true
        h.createCourse()
        await h.settle()
        h.changes.send()
        await h.coordinator.sync().value
        h.tour.startIfNeeded(hasCourses: true)
        await h.settle()
        #expect(h.notifications.requestPermissionCallCount == 1)
    }

    @Test("Granting permission rebuilds the queue after the initial unauthorized rebuild")
    func permissionGrantRebuildsReminders() async {
        let h = Harness()
        h.createCourse()
        await h.settle()
        let previousCount = h.notifications.scheduleCallCount
        h.settings.hasCompletedTour = true
        await h.coordinator.sync().value
        await h.settle()
        #expect(h.notifications.scheduleCallCount == previousCount + 2)
        #expect(h.notifications.requestPermissionCallCount == 1)
    }
}
