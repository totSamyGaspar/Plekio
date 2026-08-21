//
//  AppDelegate.swift
//  PillFlow
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    weak var router: AppRouter?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        if let medIdsStrings = userInfo["medicationIds"] as? [String],
           let timeInterval = userInfo["time"] as? TimeInterval {
            
            let medIds = medIdsStrings.compactMap { UUID(uuidString: $0) }
            let pushDate = Date(timeIntervalSince1970: timeInterval)
            
            DispatchQueue.main.async { [weak self] in
                self?.router?.handlePushNotification(medicationIds: medIds, time: pushDate)
            }
        }
        completionHandler()
    }
}
