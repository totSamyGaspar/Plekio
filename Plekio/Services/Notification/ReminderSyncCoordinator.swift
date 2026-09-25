//
//  ReminderSyncCoordinator.swift
//  Plekio
//
//  Keeps the reminder queue in step with the courses, by listening rather than
//  by being asked.
//
//  Before this, every screen that edited a course had to remember to call
//  `rescheduleAll` after its write: NewTreatmentViewModel, CourseDetailViewModel
//  (twice), CoursesListViewModel. A new screen that forgot would leave the
//  reminders describing a schedule that no longer exists — and nothing would
//  fail. Now a write only has to announce what it touched, which
//  `PersistenceController.commit` already forces it to do.
//
//  Doses are deliberately NOT handled here. Logging a dose needs its rebuild in
//  a fixed order with the lock-screen cleanup, and the notification buttons have
//  to wait for it before iOS suspends the app — so DoseLoggingUseCase runs that
//  rebuild itself and hands back a task to await. Listening to `.doses` as well
//  would rebuild twice for every tap.
//

import Combine
import Foundation

@MainActor
final class ReminderSyncCoordinator {

    private let notificationService: NotificationServiceProtocol
    private let dbService: any CourseStoring
    private var cancellables = Set<AnyCancellable>()

    /// The most recent rebuild this coordinator started, for tests and for any
    /// caller that needs to know the queue has settled.
    private(set) var lastSync: Task<Void, Never>?

    /// `changes` fires once per burst of writes the queue has to follow. Injected
    /// so a test can drive it without a store behind it.
    init(
        notificationService: NotificationServiceProtocol,
        dbService: any CourseStoring,
        changes: AnyPublisher<Void, Never>
    ) {
        self.notificationService = notificationService
        self.dbService = dbService

        changes
            .sink { [weak self] in self?.sync() }
            .store(in: &cancellables)
    }

    /// The app's coordinator: course writes from the store's own feed, debounced
    /// so that a burst — saving a course and its medications, deleting several
    /// rows — costs one rebuild rather than one each.
    convenience init(notificationService: NotificationServiceProtocol, dbService: any CourseStoring & DatabaseChangeSource) {
        self.init(
            notificationService: notificationService,
            dbService: dbService,
            changes: dbService.changes
                .publisher(for: [.courses])
                .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
                .eraseToAnyPublisher()
        )
    }

    /// Rebuilds the queue now. Also called when the app becomes active: nothing
    /// was written, but time has passed, and the queue only ever covers a window
    /// ahead of "now".
    @discardableResult
    func sync() -> Task<Void, Never> {
        let task = Task { [notificationService, dbService] in
            await notificationService.rescheduleAll(using: dbService)
        }
        lastSync = task
        return task
    }
}
