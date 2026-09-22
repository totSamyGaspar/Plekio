//
//  NotificationText.swift
//  Plekio
//

import Foundation
import UserNotifications

/// Text localised when a notification is *delivered*, not when it is scheduled.
///
/// `String(localized:)` resolves against the language in force at the moment it
/// runs and bakes the result into the request. That is wrong for this app: the
/// dose schedule is written far ahead, and a daily reminder is one repeating
/// request that fires for ever. Change the phone's language and every reminder
/// already in the queue keeps speaking the old one until something happens to
/// rebuild it.
///
/// `localizedUserNotificationString` stores the key and its arguments instead,
/// and the system looks them up as it delivers.
///
/// The keys below are invisible to Xcode's string extraction — it only sees
/// `String(localized:)` and its kin — so their entries in the catalogue are
/// marked as manually managed, or the next build would report them unused.
enum NotificationText {

    static func localized(_ key: String, _ arguments: [Any]? = nil) -> String {
        NSString.localizedUserNotificationString(forKey: key, arguments: arguments)
    }
}
