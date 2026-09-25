//
//  AppDelegate.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// The app's object graph, built on first touch.
    ///
    /// Owned here rather than by PlekioApp because a notification action can
    /// arrive on a cold launch before any SwiftUI view exists — "Take Now"
    /// logs a dose without ever showing a screen — and it needs the same graph
    /// the UI will use. `didFinishLaunching` touches it, so it exists (and the
    /// reminder sync is listening) before anything else runs.
    private(set) lazy var dependencies: AppDependencies = .live()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        _ = dependencies
        return true
    }
    
    /// Only unwraps the response. What it means and what to do about it are in
    /// NotificationIntent and NotificationResponseHandler, which can be tested —
    /// `UNNotificationResponse` cannot be built outside the system.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let intent = NotificationIntent.parse(
            userInfo: response.notification.request.content.userInfo,
            actionIdentifier: response.actionIdentifier
        ) else {
            completionHandler()
            return
        }

        Task { @MainActor [weak self] in
            // Called only once the work is done, not before it starts. iOS may
            // suspend the app as soon as this returns, and logging a dose ends
            // in a full reschedule that could be cut off halfway.
            defer { completionHandler() }
            await self?.dependencies.notificationResponses.handle(intent)
        }
    }
}
