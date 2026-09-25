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
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        // The daily reminders carry no medicationIds, so they have to be
        // recognised before the dose branch's guard drops them as malformed.
        if let kind = userInfo[DailyReminder.userInfoKey] as? String,
           let reminder = DailyReminder(rawValue: kind) {
            // The router exists from launch (it is part of the graph), so a tap
            // on a cold launch is handed over directly and parked there.
            DispatchQueue.main.async { [weak self] in
                self?.dependencies.router.open(.dailyReminder(reminder))
            }
            completionHandler()
            return
        }
        
        // Read through ReminderPayload rather than by key: these three literals
        // were written at one end and read at the other, so a typo produced a
        // reminder that looked right and named no medication.
        let medIdStrings = ReminderPayload.medicationIds(in: userInfo)
        guard !medIdStrings.isEmpty,
              let timeInterval = ReminderPayload.slotTime(in: userInfo) else {
            completionHandler()
            return
        }
        
        let medIds = medIdStrings.compactMap { UUID(uuidString: $0) }
        let names = ReminderPayload.medicationNames(in: userInfo)
        let scheduledTime = Date(timeIntervalSince1970: timeInterval)
        let action = response.actionIdentifier
        
        Task { @MainActor [weak self] in
            // Called only once the work is done, not before it starts. iOS may
            // suspend the app as soon as this returns, and logging a dose now ends
            // in a full reschedule — announcing "handled" first meant that
            // reschedule could be cut off halfway.
            defer { completionHandler() }
            
            switch action {
                // The button already answers the question, so it logs the dose instead of
                // opening a modal asking it again — it only switches to today's tab.
            case NotificationAction.take:
                guard let self else { return }
                await self.logDoses(medicationIds: medIds, scheduledTime: scheduledTime)
                self.dependencies.router.selectedTab = .today
                
            case NotificationAction.snooze:
                guard let self else { return }
                await self.dependencies.notifications.scheduleSnooze(for: medIdStrings, names: names)
                
                // Recorded, not ignored. A skip is not the absence of a log: without a
                // row nothing tells it apart from a dose the user never answered, and
                // the next rebuild puts
                // the reminder back. iOS removes the banner itself once any action is
                // chosen.
            case NotificationAction.skip:
                guard let self else { return }
                await self.skipDoses(medicationIds: medIds, scheduledTime: scheduledTime)
                
                // A plain tap on the notification body: open the app and show the modal.
            default:
                guard let self else { return }
                self.dependencies.router.open(.doseReminder(medicationIds: medIds, slot: scheduledTime))
            }
        }
    }
    
    /// "Take Now" on the notification: logs what of the slot is still open.
    ///
    /// Idempotent: `openDoses` drops anything already taken, so a second press
    /// changes nothing. Waits for the reminder rebuild before returning, because
    /// iOS may suspend the app once the response is reported handled.
    private func logDoses(medicationIds: [UUID], scheduledTime: Date) async {
        let doseLogging = dependencies.doseLogging
        let open = doseLogging.openDoses(medicationIds: medicationIds, at: scheduledTime)

        guard let outcome = dependencies.errorPresenter.attempt({ try doseLogging.markTaken(open) }) else { return }
        await outcome.waitForReminders()
    }

    /// "Skip" on the notification. Idempotent the same way: `openDoses` drops
    /// what is taken, `markSkipped` what is already skipped.
    private func skipDoses(medicationIds: [UUID], scheduledTime: Date) async {
        let doseLogging = dependencies.doseLogging
        let open = doseLogging.openDoses(medicationIds: medicationIds, at: scheduledTime)

        guard let outcome = dependencies.errorPresenter.attempt({ try doseLogging.markSkipped(open) }) else { return }
        await outcome.waitForReminders()
    }
}
