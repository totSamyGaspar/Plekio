//
//  AppDependencies.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
import Observation

/// The composition root. `@Observable` only so it travels through
/// `.environment(_:)` by type; nothing changes after init.
@Observable
@MainActor
final class AppDependencies {

    // MARK: - Services

    let database: any DatabaseServiceProtocol
    let notifications: any NotificationServiceProtocol

    /// One photo cache shared by the database, view models and views.
    /// Concrete because Settings measures its size on disk.
    let photoCache: ImageCache

    /// The root points `@AppStorage` at the same defaults domain.
    let settings: SettingsStore
    let appLock: AppLock

    /// Handed out as `any ErrorReporting`; only MainTabView needs the concrete type.
    let errorPresenter: AppErrorPresenter
    /// Short confirmations and hints, shown over every screen.
    let toasts = ToastCenter()
    /// The first-run tour; unlocks the contextual tips when it's over.
    let tour: TourCoordinator

    /// The store file, for the storage-usage row in Settings. Nil in previews.
    let storeURL: URL?

    // MARK: - Use cases

    /// Courses as snapshots; no SwiftData model reaches a screen through it.
    let courseRepository: any CourseRepository

    /// Diary entries and blood-pressure readings as snapshots.
    let diaryRepository: any DiaryRepository

    let doseLogging: any DoseLoggingUseCaseProtocol
    /// Validates blood-pressure rules on write.
    let bloodPressureLogging: BloodPressureLogging
    let courseEditing: any CourseEditingUseCaseProtocol

    /// The single undo window for dose actions, shared by dashboard and notification modal.
    let doseUndo: DoseUndoCenter

    let doseSheetActions: DoseSheetActions

    let dailyReminderArming: DailyReminderArming

    /// Held for its subscription, which rebuilds reminders after course writes.
    let reminderSync: ReminderSyncCoordinator

    /// Lives here, not in the SwiftUI root, so it exists before the first screen.
    let router: AppRouter

    /// Built eagerly so a cold-launch "Take Now" uses the same use case and router as the UI.
    let notificationResponses: NotificationResponseHandler

    /// One instance so the whole app agrees on "now".
    let time: any TimeSource

    // MARK: - Init

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
        appLock = AppLock(settings: settings, authenticator: DeviceAuthenticator())
        self.errorPresenter = errorPresenter
        self.storeURL = storeURL

        doseLogging = DoseLoggingUseCase(dbService: database, notificationService: notifications)
        doseUndo = DoseUndoCenter(doseLogging: doseLogging, errors: errorPresenter, time: time)
        doseSheetActions = DoseSheetActions(doseLogging: doseLogging, notifications: notifications, undo: doseUndo, errors: errorPresenter)
        dailyReminderArming = DailyReminderArming(notifications: notifications)
        courseRepository = SwiftDataCourseRepository(store: database)
        diaryRepository = SwiftDataDiaryRepository(store: database)
        bloodPressureLogging = BloodPressureLogging(diary: diaryRepository, errors: errorPresenter, time: time)
        courseEditing = CourseEditingUseCase(courses: courseRepository, notificationService: notifications, time: time)
        let reminderSync = ReminderSyncCoordinator(
            notificationService: notifications,
            dbService: database,
            canRequestPermission: { settings.hasCompletedTour }
        )
        self.reminderSync = reminderSync
        router = AppRouter()
        tour = TourCoordinator(settings: settings, router: router, onFinish: {
            PlekioTips.tourFinished = true
            reminderSync.sync()
        })
        notificationResponses = NotificationResponseHandler(
            doseLogging: doseLogging,
            notifications: notifications,
            router: router,
            errors: errorPresenter
        )
    }

    // MARK: - Factories

    /// The app's graph: the on-disk store and the real notification centre.
    static func live() -> AppDependencies {
        // Created first: the store may report an in-memory fallback while being built.
        let errorPresenter = AppErrorPresenter()
        let time = SystemTime()
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
    /// In-memory store, so a preview can never touch the user's data.
    static let preview: AppDependencies = {
        let errorPresenter = AppErrorPresenter()
        // Separate defaults domain so previews never change the app's settings.
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
