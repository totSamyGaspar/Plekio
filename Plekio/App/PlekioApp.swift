//
//  PlekioApp.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

@main
struct PlekioApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        MainTabView.configureTabBarAppearance()
        AppAppearance.configureSliders()
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(appDelegate.dependencies.router)
                // The composition root, for every screen below — see AppDependencies.
                .environment(appDelegate.dependencies)
                // Photo views read the loader from here rather than from ImageCache.shared.
                .environment(\.imageLoader, appDelegate.dependencies.photoCache)
                .environment(\.databaseChanges, appDelegate.dependencies.database.changes)
                // Every @AppStorage below reads the domain SettingsStore writes.
                .defaultAppStorage(appDelegate.dependencies.settings.defaults)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        refreshAllNotifications()
                    }
                }
        }
    }
    /// Nothing was written, but time has passed: the queue only covers a window
    /// ahead of "now", so it is topped up whenever the user comes back.
    private func refreshAllNotifications() {
        appDelegate.dependencies.reminderSync.sync()
    }
}
