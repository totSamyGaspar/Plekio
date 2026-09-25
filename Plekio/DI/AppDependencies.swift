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

    /// Photo files and decoded photos — one cache, shared by the database (as
    /// PhotoStoring), view models, and views (as ImageLoading, through the
    /// environment). Concrete: Settings measures its size on disk.
    let photoCache: ImageCache

    /// Owned here, not reached as a singleton. View models and the storage layer
    /// get it as `any ErrorReporting`; only MainTabView, which shows the alert,
    /// needs the concrete type.
    let errorPresenter: AppErrorPresenter

    /// The store file, for the storage-usage row in Settings. Nil in previews.
    let storeURL: URL?

    // MARK: - Use cases

    /// Courses as snapshots, by id — what the courses screens read. No
    /// SwiftData model reaches a screen through it.
    let courseRepository: any CourseRepository

    let doseLogging: any DoseLoggingUseCaseProtocol
    let courseEditing: any CourseEditingUseCaseProtocol

    /// Kept for its subscription: it rebuilds the reminder queue after course
    /// writes for as long as this object lives, which is as long as the app.
    let reminderSync: ReminderSyncCoordinator

    init(
        database: any DatabaseServiceProtocol,
        notifications: any NotificationServiceProtocol,
        mediaPicker: any MediaPickerServiceProtocol,
        photoCache: ImageCache,
        errorPresenter: AppErrorPresenter,
        storeURL: URL? = nil
    ) {
        self.database = database
        self.notifications = notifications
        self.mediaPicker = mediaPicker
        self.photoCache = photoCache
        self.errorPresenter = errorPresenter
        self.storeURL = storeURL

        doseLogging = DoseLoggingUseCase(dbService: database, notificationService: notifications)
        courseRepository = SwiftDataCourseRepository(store: database)
        courseEditing = CourseEditingUseCase(courses: courseRepository, notificationService: notifications)
        reminderSync = ReminderSyncCoordinator(notificationService: notifications, dbService: database)
    }

    /// The app's graph: the on-disk store and the real notification centre.
    static func live() -> AppDependencies {
        // Created first: the store reports into it if it has to fall back to
        // memory, which happens while it is being built.
        let errorPresenter = AppErrorPresenter()
        // The one place the app's photo cache is chosen.
        let photoCache = ImageCache.shared
        let database = DatabaseService(photos: photoCache, errors: errorPresenter)

        return AppDependencies(
            database: database,
            notifications: NotificationService(),
            mediaPicker: MediaPickerService(),
            photoCache: photoCache,
            errorPresenter: errorPresenter,
            storeURL: database.persistence.storeURL
        )
    }

    #if DEBUG
    /// For SwiftUI previews of screens that create other screens: an in-memory
    /// store, so a preview can never touch the user's data.
    static let preview: AppDependencies = {
        let errorPresenter = AppErrorPresenter()
        return AppDependencies(
            database: DatabaseService(inMemoryForTesting: true, photos: ImageCache.shared, errors: errorPresenter),
            notifications: NotificationService(),
            mediaPicker: MediaPickerService(),
            photoCache: ImageCache.shared,
            errorPresenter: errorPresenter
        )
    }()
    #endif
}
