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
            AppLockRootView()
                .environmentObject(appDelegate.dependencies.router)
                .environment(appDelegate.dependencies)
                .environment(\.imageLoader, appDelegate.dependencies.photoCache)
                .environment(\.databaseChanges, appDelegate.dependencies.database.changes)
                // @AppStorage below must read the same defaults SettingsStore writes.
                .defaultAppStorage(appDelegate.dependencies.settings.defaults)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        refreshAllNotifications()
                    }
                }
        }
    }

    // MARK: - Helpers

    /// The notification queue only covers a window ahead of now, so top it up on return.
    private func refreshAllNotifications() {
        appDelegate.dependencies.reminderSync.sync()
    }
}
