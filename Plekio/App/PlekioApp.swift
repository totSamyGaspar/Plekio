//
//  PlekioApp.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

@main
struct PlekioApp: App {

    // MARK: - Properties

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Init

    init() {
        MainTabView.configureTabBarAppearance()
        AppAppearance.configureSliders()
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            Group {
                if let dependencies = appDelegate.launcher.dependencies {
                    AppLockRootView()
                        .environmentObject(dependencies.router)
                        .environment(dependencies)
                        .environment(\.imageLoader, dependencies.photoCache)
                        .environment(\.databaseChanges, dependencies.database.changes)
                        // @AppStorage below must read the same defaults SettingsStore writes.
                        .defaultAppStorage(dependencies.settings.defaults)
                } else {
                    StorageRecoveryView(launcher: appDelegate.launcher)
                }
            }
            // A tap on a widget. Parked in the router like a reminder's tap, so it
            // opens after Face ID when the app is locked.
            .onOpenURL { url in openWidgetLink(url) }
            // `initial`: a cold launch can arrive already active, with no change to observe.
            .onChange(of: scenePhase, initial: true) { _, newPhase in
                if newPhase == .active {
                    becameActive()
                } else if newPhase == .background {
                    BackgroundRefresh.schedule()
                }
            }
        }
    }

    // MARK: - Helpers

    private func openWidgetLink(_ url: URL) {
        guard let link = WidgetLink(url: url), let router = appDelegate.launcher.dependencies?.router else { return }
        switch link {
        case .today:
            router.selectedTab = .today
        case .dose(let slot, let ids):
            // Opens the take-dose sheet for what is still open, or just Today if nothing is.
            router.open(.doseReminder(medicationIds: ids, slot: slot))
        // The same forms the daily reminders open, on the Diary tab.
        case .diaryCheckIn:
            router.open(.dailyReminder(.diary))
        case .bloodPressureEntry:
            router.open(.dailyReminder(.bloodPressure))
        }
    }

    /// The notification queue only covers a window ahead of now, so top it up on
    /// return. With the store still closed, try it again instead: the device may
    /// have been locked or short of space.
    private func becameActive() {
        let launcher = appDelegate.launcher
        if let dependencies = launcher.dependencies {
            dependencies.reviewPrompt.recordActiveDay()
            dependencies.reminderSync.sync()
            // Also rolls the snapshot over to a new day the app wasn't open for.
            dependencies.widgetSnapshots.refresh()
        } else {
            launcher.retry()
        }
    }
}
