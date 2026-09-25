//
//  AppDelegate.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// A notification tap can arrive before SwiftUI has drawn the first screen and
    /// assigned the router, so the payload is buffered and replayed the moment the
    /// router appears. Without this a tap on a cold launch was silently lost.
    weak var router: AppRouter? {
        didSet { flushBufferedPush() }
    }
    
    private var bufferedPush: (medicationIds: [UUID], time: Date)?
    private var bufferedReminder: DailyReminder?
    
    private func flushBufferedPush() {
        guard let router else { return }
        
        if let push = bufferedPush {
            bufferedPush = nil
            router.handlePushNotification(medicationIds: push.medicationIds, time: push.time)
        }
        
        if let reminder = bufferedReminder {
            bufferedReminder = nil
            router.handleReminder(reminder)
        }
    }
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
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
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let router = self.router {
                    router.handleReminder(reminder)
                } else {
                    self.bufferedReminder = reminder
                }
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
                self.router?.selectedTab = 0
                
            case NotificationAction.snooze:
                let notifService = DIContainer.shared.resolve(NotificationServiceProtocol.self)
                await notifService.scheduleSnooze(for: medIdStrings, names: names)
                
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
                if let router = self.router {
                    router.handlePushNotification(medicationIds: medIds, time: scheduledTime)
                } else {
                    self.bufferedPush = (medIds, scheduledTime)
                }
            }
        }
    }
    
    /// "Take Now" on the notification: logs what of the slot is still open.
    ///
    /// Idempotent: `openDoses` drops anything already taken, so a second press
    /// changes nothing. Waits for the reminder rebuild before returning, because
    /// iOS may suspend the app once the response is reported handled.
    private func logDoses(medicationIds: [UUID], scheduledTime: Date) async {
        let doseLogging = DIContainer.shared.resolve(DoseLoggingUseCaseProtocol.self)
        let open = doseLogging.openDoses(medicationIds: medicationIds, at: scheduledTime)

        guard let outcome = AppErrorPresenter.shared.attempt({ try doseLogging.markTaken(open) }) else { return }
        await outcome.waitForReminders()
    }

    /// "Skip" on the notification. Idempotent the same way: `openDoses` drops
    /// what is taken, `markSkipped` what is already skipped.
    private func skipDoses(medicationIds: [UUID], scheduledTime: Date) async {
        let doseLogging = DIContainer.shared.resolve(DoseLoggingUseCaseProtocol.self)
        let open = doseLogging.openDoses(medicationIds: medicationIds, at: scheduledTime)

        guard let outcome = AppErrorPresenter.shared.attempt({ try doseLogging.markSkipped(open) }) else { return }
        await outcome.waitForReminders()
    }
}
