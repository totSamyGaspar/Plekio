//
//  ReminderPayload.swift
//  Plekio
//

import Foundation
import UserNotifications

/// The userInfo a dose reminder carries, and the only place those keys are
/// spelled.
///
/// They were string literals at five sites — written on scheduling, read on
/// regrouping, on delivered cleanup and in AppDelegate — so a typo in one of them
/// produced a reminder that looked right and behaved as though it named no
/// medication at all.
nonisolated enum ReminderPayload {

    static let medicationIdsKey = "medicationIds"
    /// Names are stored as well as ids: a group reminder has to be rebuilt without
    /// one medication when that one is cancelled, and a snoozed notification still
    /// has to know what it is reminding about.
    static let medicationNamesKey = "medicationNames"
    static let slotTimeKey = "time"

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

/// One queued or delivered reminder, reduced to what the rules actually read.
///
/// This exists so those rules can be tested. `UNNotification` cannot be
/// constructed outside the system, so anything that took one — which was all of
/// the cancellation and regrouping logic — could only ever be exercised against a
/// real notification centre, which in practice meant not at all.
nonisolated struct ReminderSnapshot {

    let identifier: String
    let medicationIds: [String]
    let medicationNames: [String]
    /// When the dose is due, as it was written into userInfo. Nil for anything
    /// that is not a dose reminder — the daily diary and blood-pressure ones.
    let slotTime: TimeInterval?
    /// Kept so a group reminder can be rebuilt on the same schedule after one
    /// medication drops out of it.
    let trigger: UNNotificationTrigger?

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

    /// Whether this reminder is for the given slot.
    ///
    /// Compared with a second of slack: the time went through userInfo as a
    /// `Double`, and a round-tripped floating-point value should not be asked for
    /// exact equality.
    func covers(slot: Date) -> Bool {
        guard let slotTime else { return false }
        return abs(slotTime - slot.timeIntervalSince1970) < 1
    }
}
