//
//  ReminderDelivery.swift
//  Plekio
//
//  Created by Edward Gasparian on 09.11.2026.
//

import UserNotifications

/// Whether a scheduled reminder can reach the person at all.
nonisolated enum ReminderDelivery: Equatable, Sendable {
    case on
    /// Not asked yet: the prompt comes with the first course.
    case notAsked
    /// Denied, or allowed with every place a reminder could show turned off.
    case off

    init(authorization: UNAuthorizationStatus, showsAnywhere: Bool) {
        switch authorization {
        case .notDetermined: self = .notAsked
        case .denied: self = .off
        default: self = showsAnywhere ? .on : .off
        }
    }
}
