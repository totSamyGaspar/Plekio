//
//  AppDependencies+UITesting.swift
//  Plekio
//
//  Created by Edward Gasparian on 18.11.2026.
//

#if DEBUG
import Foundation

// MARK: - UI Testing

extension AppDependencies {

    /// The graph for a UI-testing launch: an in-memory store, its own defaults
    /// domain and photo folder, no reminders and no tip jar. Built fresh on every
    /// launch, so each test starts from its seed and nothing else.
    static func uiTesting(_ launch: UITestingLaunch) -> AppDependencies {
        let errorPresenter = AppErrorPresenter()
        // The real clock: see UITestingSeed for why not a fixed one.
        let time = SystemTime()

        guard let defaults = UserDefaults(suiteName: UITestingLaunch.defaultsSuite) else {
            // Never fall back to .standard: the wipe below would erase the user's settings.
            fatalError("UI testing: can't open the \(UITestingLaunch.defaultsSuite) defaults domain")
        }
        defaults.removePersistentDomain(forName: UITestingLaunch.defaultsSuite)
        let settings = SettingsStore(defaults: defaults)
        if launch.seed != .onboarding {
            settings.hasSeenOnboarding = true
            // The tour would cover the screen the test is about to tap.
            settings.hasCompletedTour = true
        }

        let photos = ImageCache(directory: FileManager.default.temporaryDirectory
            .appending(path: "PlekioUITestingPhotos-\(UUID().uuidString)", directoryHint: .isDirectory))
        let database = DatabaseService(inMemoryForTesting: true, photos: photos, errors: errorPresenter, time: time)

        let dependencies = AppDependencies(
            database: database,
            notifications: UITestingNotificationService(),
            photoCache: photos,
            settings: settings,
            errorPresenter: errorPresenter,
            tipJar: DisabledTipJar(),
            time: time
        )
        UITestingSeed.apply(launch.seed, to: database, time: time)
        return dependencies
    }
}
#endif
