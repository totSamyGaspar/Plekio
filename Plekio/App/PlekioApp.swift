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
            // `initial`: a cold launch can arrive already active, with no change to observe.
            .onChange(of: scenePhase, initial: true) { _, newPhase in
                if newPhase == .active {
                    becameActive()
                }
            }
        }
    }

    // MARK: - Helpers

    /// The notification queue only covers a window ahead of now, so top it up on
    /// return. With the store still closed, try it again instead: the device may
    /// have been locked or short of space.
    private func becameActive() {
        let launcher = appDelegate.launcher
        if let dependencies = launcher.dependencies {
            dependencies.reviewPrompt.recordActiveDay()
            dependencies.reminderSync.sync()
        } else {
            launcher.retry()
        }
    }
}
