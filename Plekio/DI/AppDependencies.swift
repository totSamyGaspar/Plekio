//
//  AppDependencies.swift
//  Plekio
//
//  The composition root: the one place the app's object graph is assembled.
//
//  Replaces the Swinject container, which every screen reached through
//  `DIContainer.shared.resolve(...)` — a service locator. Dependencies were
//  hidden inside view initialisers, and a missing registration was a
//  `fatalError` at run time on whichever screen happened to ask. Here the graph
//  is plain Swift: forget a dependency and it does not compile.
//
//  How it travels: built once (AppDelegate owns it — see there for why), put
//  into the SwiftUI environment at the root, and read by the views that create
//  other screens. A view does not build its own view model; its parent builds
//  it through the factory methods in AppDependencies+ViewModels.
//

import Foundation
import Observation

/// `@Observable` only so it can travel through `.environment(_:)` by type —
/// nothing in it changes after init.
@Observable
@MainActor
final class AppDependencies {

    // MARK: - Services

    let database: any DatabaseServiceProtocol
    let notifications: any NotificationServiceProtocol
    let mediaPicker: any MediaPickerServiceProtocol

    // MARK: - Use cases

    let doseLogging: any DoseLoggingUseCaseProtocol
    let courseEditing: any CourseEditingUseCaseProtocol

    /// Kept for its subscription: it rebuilds the reminder queue after course
    /// writes for as long as this object lives, which is as long as the app.
    let reminderSync: ReminderSyncCoordinator

    init(
        database: any DatabaseServiceProtocol,
        notifications: any NotificationServiceProtocol,
        mediaPicker: any MediaPickerServiceProtocol
    ) {
        self.database = database
        self.notifications = notifications
        self.mediaPicker = mediaPicker

        doseLogging = DoseLoggingUseCase(dbService: database, notificationService: notifications)
        courseEditing = CourseEditingUseCase(dbService: database, notificationService: notifications)
        reminderSync = ReminderSyncCoordinator(notificationService: notifications, dbService: database)
    }

    /// The app's graph: the on-disk store and the real notification centre.
    static func live() -> AppDependencies {
        AppDependencies(
            database: DatabaseService.shared,
            notifications: NotificationService(),
            mediaPicker: MediaPickerService()
        )
    }

    #if DEBUG
    /// For SwiftUI previews of screens that create other screens: an in-memory
    /// store, so a preview can never touch the user's data.
    static let preview = AppDependencies(
        database: DatabaseService(inMemoryForTesting: true),
        notifications: NotificationService(),
        mediaPicker: MediaPickerService()
    )
    #endif
}
