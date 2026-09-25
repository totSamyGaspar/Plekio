//
//  ReminderPayload.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Foundation
import UserNotifications

// MARK: - ReminderPayload

/// The userInfo a dose reminder carries; the only place its keys are spelled.
nonisolated enum ReminderPayload {

    // MARK: - Keys

    static let medicationIdsKey = "medicationIds"
    /// Names are stored too, for regrouping and snoozing without a database read.
    static let medicationNamesKey = "medicationNames"
    static let slotTimeKey = "time"

    // MARK: - Encoding

    static func userInfo(
        medicationIds: [String],
        medicationNames: [String],
        triggerDate: Date
    ) -> [String: Any] {
        [
            medicationIdsKey: medicationIds,
            medicationNamesKey: medicationNames,
            slotTimeKey: triggerDate.timeIntervalSince1970
        ]
    }

    // MARK: - Decoding

    static func medicationIds(in userInfo: [AnyHashable: Any]) -> [String] {
        userInfo[medicationIdsKey] as? [String] ?? []
    }

    static func medicationNames(in userInfo: [AnyHashable: Any]) -> [String] {
        userInfo[medicationNamesKey] as? [String] ?? []
    }

    static func slotTime(in userInfo: [AnyHashable: Any]) -> TimeInterval? {
        userInfo[slotTimeKey] as? TimeInterval
    }
}

// MARK: - ReminderSnapshot

/// A queued or delivered reminder, reduced to what the rules read; constructible in tests.
nonisolated struct ReminderSnapshot {

    // MARK: - Properties

    let identifier: String
    let medicationIds: [String]
    let medicationNames: [String]
    /// When the dose is due; nil for daily (diary / blood pressure) reminders.
    let slotTime: TimeInterval?
    /// Kept to rebuild a regrouped reminder on the same schedule.
    let trigger: UNNotificationTrigger?

    // MARK: - Init

    init(
        identifier: String,
        medicationIds: [String],
        medicationNames: [String],
        slotTime: TimeInterval?,
        trigger: UNNotificationTrigger? = nil
    ) {
        self.identifier = identifier
        self.medicationIds = medicationIds
        self.medicationNames = medicationNames
        self.slotTime = slotTime
        self.trigger = trigger
    }

    init(request: UNNotificationRequest) {
        let userInfo = request.content.userInfo
        self.init(
            identifier: request.identifier,
            medicationIds: ReminderPayload.medicationIds(in: userInfo),
            medicationNames: ReminderPayload.medicationNames(in: userInfo),
            slotTime: ReminderPayload.slotTime(in: userInfo),
            trigger: request.trigger
        )
    }

    // MARK: - Matching

    /// Whether this reminder is for `slot`, with a second of slack for the round-tripped Double.
    func covers(slot: Date) -> Bool {
        guard let slotTime else { return false }
        return abs(slotTime - slot.timeIntervalSince1970) < 1
    }
}
