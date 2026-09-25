//
//  NotificationResponseHandler.swift
//  Plekio
//
//  What a tap on a reminder means, and doing it.
//
//  This used to live in AppDelegate's `didReceive`, where it could not be
//  tested: `UNNotificationResponse` cannot be constructed outside the system.
//  It is split in two so neither half needs one. `NotificationIntent.parse`
//  reads plain userInfo and an action identifier; the handler acts on the
//  result through the same use case, router and error reporter the UI uses.
//  AppDelegate is left with unwrapping the response and calling the
//  completion handler.
//

import Foundation

/// A notification response, reduced to what the user asked for.
enum NotificationIntent: Equatable {
    /// A tap on a daily (diary / blood pressure) reminder.
    case openDailyReminder(DailyReminder)
    /// "Take Now": log the slot without showing a screen.
    case take(medicationIds: [UUID], slot: Date)
    /// "Skip": record the skip, so the next rebuild does not bring the reminder back.
    case skip(medicationIds: [UUID], slot: Date)
    /// "Snooze". Ids stay strings: that is what the snoozed reminder carries.
    case snooze(medicationIds: [String], names: [String])
    /// A plain tap on a dose reminder: open the app on it.
    case openDoseReminder(medicationIds: [UUID], slot: Date)

    /// Nil for a payload that names nothing to act on — malformed, or from an
    /// older build.
    static func parse(userInfo: [AnyHashable: Any], actionIdentifier: String) -> NotificationIntent? {
        // Daily reminders carry no medication ids, so they are recognised before
        // the dose branch would drop them as malformed.
        if let kind = userInfo[DailyReminder.userInfoKey] as? String,
           let reminder = DailyReminder(rawValue: kind) {
            return .openDailyReminder(reminder)
        }

        let idStrings = ReminderPayload.medicationIds(in: userInfo)
        guard !idStrings.isEmpty,
              let interval = ReminderPayload.slotTime(in: userInfo) else { return nil }

        let ids = idStrings.compactMap(UUID.init(uuidString:))
        let slot = Date(timeIntervalSince1970: interval)

        switch actionIdentifier {
        case NotificationAction.take:
            return .take(medicationIds: ids, slot: slot)
        case NotificationAction.skip:
            return .skip(medicationIds: ids, slot: slot)
        case NotificationAction.snooze:
            return .snooze(medicationIds: idStrings, names: ReminderPayload.medicationNames(in: userInfo))
        default:
            return .openDoseReminder(medicationIds: ids, slot: slot)
        }
    }
}

@MainActor
final class NotificationResponseHandler {

    private let doseLogging: any DoseLoggingUseCaseProtocol
    private let notifications: any NotificationServiceProtocol
    private let router: AppRouter
    private let errors: any ErrorReporting

    init(doseLogging: any DoseLoggingUseCaseProtocol,
         notifications: any NotificationServiceProtocol,
         router: AppRouter,
         errors: any ErrorReporting) {
        self.doseLogging = doseLogging
        self.notifications = notifications
        self.router = router
        self.errors = errors
    }

    /// Returns once the work is done, reminder rebuild included: iOS may
    /// suspend the app as soon as the response is reported handled.
    func handle(_ intent: NotificationIntent) async {
        switch intent {
        case .openDailyReminder(let reminder):
            // The router exists from launch, so on a cold launch the link is
            // parked there until the UI is up.
            router.open(.dailyReminder(reminder))

        case .take(let ids, let slot):
            // The button already answers the question, so there is no modal
            // asking it again — only a switch to today's tab.
            await write(ids, slot) { try self.doseLogging.markTaken($0) }
            router.selectedTab = .today

        case .skip(let ids, let slot):
            await write(ids, slot) { try self.doseLogging.markSkipped($0) }

        case .snooze(let ids, let names):
            await notifications.scheduleSnooze(for: ids, names: names)

        case .openDoseReminder(let ids, let slot):
            router.open(.doseReminder(medicationIds: ids, slot: slot))
        }
    }

    /// Idempotent: `openDoses` drops what is already taken, the use case what
    /// is already skipped — a second press changes nothing.
    private func write(_ ids: [UUID], _ slot: Date,
                       _ command: ([PillDose]) throws -> DoseLogOutcome) async {
        let open = doseLogging.openDoses(medicationIds: ids, at: slot)
        guard let outcome = errors.attempt({ try command(open) }) else { return }
        await outcome.waitForReminders()
    }
}
