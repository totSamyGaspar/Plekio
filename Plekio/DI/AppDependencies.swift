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

    /// Photo files and decoded photos — one cache, shared by the database (as
    /// PhotoStoring), view models, and views (as ImageLoading, through the
    /// environment). Concrete: Settings measures its size on disk.
    let photoCache: ImageCache

    /// Flags and preferences in UserDefaults. The root points `@AppStorage` at
    /// the same domain with `.defaultAppStorage(settings.defaults)`.
    let settings: SettingsStore

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

    /// Diary entries and blood-pressure readings as snapshots, by id.
    let diaryRepository: any DiaryRepository

    let doseLogging: any DoseLoggingUseCaseProtocol
    /// Saving a blood-pressure reading, rules checked on the write.
    let bloodPressureLogging: BloodPressureLogging
    let courseEditing: any CourseEditingUseCaseProtocol

    /// The one undo window for dose actions — the dashboard's and the
    /// notification modal's alike.
    let doseUndo: DoseUndoCenter

    /// Switching the daily reminders on and off, permission included.
    let dailyReminderArming: DailyReminderArming

    /// Kept for its subscription: it rebuilds the reminder queue after course
    /// writes for as long as this object lives, which is as long as the app.
    let reminderSync: ReminderSyncCoordinator

    /// Navigation state and the entry point for deep links. Here, not in the
    /// SwiftUI root, so it exists before the first screen does.
    let router: AppRouter

    /// What a tap on a reminder does. Built with the graph, not on demand, so a
    /// "Take Now" on a cold launch uses the same use case and router as the UI.
    let notificationResponses: NotificationResponseHandler

    /// "Now" for every rule that depends on it — see TimeSource. One instance,
    /// so the whole app agrees on the time.
    let time: any TimeSource

    init(
        database: any DatabaseServiceProtocol,
        notifications: any NotificationServiceProtocol,
        photoCache: ImageCache,
        settings: SettingsStore,
        errorPresenter: AppErrorPresenter,
        storeURL: URL? = nil,
        time: any TimeSource = SystemTime()
    ) {
        self.time = time
        self.database = database
        self.notifications = notifications
        self.photoCache = photoCache
        self.settings = settings
        self.errorPresenter = errorPresenter
        self.storeURL = storeURL

        doseLogging = DoseLoggingUseCase(dbService: database, notificationService: notifications)
        doseUndo = DoseUndoCenter(doseLogging: doseLogging, errors: errorPresenter, time: time)
        dailyReminderArming = DailyReminderArming(notifications: notifications)
        courseRepository = SwiftDataCourseRepository(store: database)
        diaryRepository = SwiftDataDiaryRepository(store: database)
        bloodPressureLogging = BloodPressureLogging(diary: diaryRepository, errors: errorPresenter, time: time)
        courseEditing = CourseEditingUseCase(courses: courseRepository, notificationService: notifications, time: time)
        reminderSync = ReminderSyncCoordinator(notificationService: notifications, dbService: database)
        router = AppRouter()
        notificationResponses = NotificationResponseHandler(
            doseLogging: doseLogging,
            notifications: notifications,
            router: router,
            errors: errorPresenter
        )
    }

    /// The app's graph: the on-disk store and the real notification centre.
    static func live() -> AppDependencies {
        // Created first: the store reports into it if it has to fall back to
        // memory, which happens while it is being built.
        let errorPresenter = AppErrorPresenter()
        let time = SystemTime()
        // The one place the app's photo cache is chosen.
        let photoCache = ImageCache.shared
        let database = DatabaseService(photos: photoCache, errors: errorPresenter, time: time)
        let settings = SettingsStore(defaults: .standard)

        return AppDependencies(
            database: database,
            notifications: NotificationService(settings: settings, time: time),
            photoCache: photoCache,
            settings: settings,
            errorPresenter: errorPresenter,
            storeURL: database.persistence.storeURL,
            time: time
        )
    }

    #if DEBUG
    /// For SwiftUI previews of screens that create other screens: an in-memory
    /// store, so a preview can never touch the user's data.
    static let preview: AppDependencies = {
        let errorPresenter = AppErrorPresenter()
        // Its own domain, so a preview toggling a setting never changes the app's.
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "PlekioPreviews") ?? .standard)
        return AppDependencies(
            database: DatabaseService(inMemoryForTesting: true, photos: ImageCache.shared, errors: errorPresenter),
            notifications: NotificationService(settings: settings, time: SystemTime()),
            photoCache: ImageCache.shared,
            settings: settings,
            errorPresenter: errorPresenter
        )
    }()
    #endif
}
