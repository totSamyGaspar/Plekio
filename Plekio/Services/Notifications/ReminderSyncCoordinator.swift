//
//  ReminderSyncCoordinator.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Combine
import Foundation

/// Rebuilds the reminder queue whenever courses change, and asks for notification
/// permission once a course exists and the first-run tour has finished or been skipped.
@MainActor
final class ReminderSyncCoordinator {

    // MARK: - Properties

    private let notificationService: NotificationServiceProtocol
    private let dbService: any CourseStoring
    private let canRequestPermission: () -> Bool
    private var cancellables = Set<AnyCancellable>()

    /// The most recent rebuild started, for awaiting a settled queue.
    private(set) var lastSync: Task<Void, Never>?
    private(set) var lastPermissionRequest: Task<Void, Never>?

    /// Once per launch; iOS itself shows the prompt only the first time.
    private var didAskForPermission = false

    // MARK: - Init

    /// `changes` fires once per burst of writes the queue has to follow.
    init(
        notificationService: NotificationServiceProtocol,
        dbService: any CourseStoring,
        changes: AnyPublisher<Void, Never>,
        canRequestPermission: @escaping () -> Bool = { false }
    ) {
        self.notificationService = notificationService
        self.dbService = dbService
        self.canRequestPermission = canRequestPermission

        changes
            .sink { [weak self] in self?.sync() }
            .store(in: &cancellables)
    }

    /// Follows course writes from the store, debounced so a burst costs one rebuild.
    convenience init(
        notificationService: NotificationServiceProtocol,
        dbService: any CourseStoring & DatabaseChangeSource,
        canRequestPermission: @escaping () -> Bool
    ) {
        self.init(
            notificationService: notificationService,
            dbService: dbService,
            changes: dbService.changes
                .publisher(for: [.courses])
                .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
                .eraseToAnyPublisher(),
            canRequestPermission: canRequestPermission
        )
    }

    // MARK: - Sync

    /// Rebuilds the queue now; also called on app activation since the window moves with time.
    @discardableResult
    func sync() -> Task<Void, Never> {
        askForPermissionIfNeeded()

        let task = Task { [notificationService, dbService] in
            await notificationService.rescheduleAll(using: dbService)
        }
        lastSync = task
        return task
    }

    // MARK: - Permission

    /// Not awaited by the rebuild: the prompt may stay up, and the queue must not wait for it.
    private func askForPermissionIfNeeded() {
        guard !didAskForPermission, canRequestPermission(), !dbService.fetchAllCourses().isEmpty else { return }
        didAskForPermission = true
        lastPermissionRequest = Task { [weak self, notificationService] in
            if await notificationService.requestPermission() {
                // The first rebuild may have run before permission was granted.
                _ = self?.sync()
            }
        }
    }
}
