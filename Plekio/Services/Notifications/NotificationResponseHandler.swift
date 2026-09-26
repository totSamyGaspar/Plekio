//
//  NotificationResponseHandler.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - NotificationIntent

/// A notification response, reduced to what the user asked for.
enum NotificationIntent: Equatable {
    /// A tap on a daily (diary / blood pressure) reminder.
    case openDailyReminder(DailyReminder)
    /// "Take Now": log the slot without showing a screen.
    case take(medicationIds: [UUID], slot: Date)
    /// "Skip": recorded so the next rebuild does not bring the reminder back.
    case skip(medicationIds: [UUID], slot: Date)
    /// "Snooze". Ids stay strings: that is what the snoozed reminder carries.
    case snooze(medicationIds: [String], names: [String], slot: Date)
    /// A plain tap on a dose reminder: open the app on it.
    case openDoseReminder(medicationIds: [UUID], slot: Date)

    // MARK: - Parsing

    /// Nil for a payload that names nothing to act on (malformed or from an older build).
    static func parse(userInfo: [AnyHashable: Any], actionIdentifier: String) -> NotificationIntent? {
        // Checked first: daily reminders carry no medication ids.
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
            return .snooze(medicationIds: idStrings, names: ReminderPayload.medicationNames(in: userInfo), slot: slot)
        default:
            return .openDoseReminder(medicationIds: ids, slot: slot)
        }
    }
}

// MARK: - NotificationResponseHandler

/// Carries out a parsed notification response.
@MainActor
final class NotificationResponseHandler {

    // MARK: - Properties

    private let doseLogging: any DoseLoggingUseCaseProtocol
    private let notifications: any NotificationServiceProtocol
    private let router: AppRouter
    private let errors: any ErrorReporting

    // MARK: - Init

    init(doseLogging: any DoseLoggingUseCaseProtocol,
         notifications: any NotificationServiceProtocol,
         router: AppRouter,
         errors: any ErrorReporting) {
        self.doseLogging = doseLogging
        self.notifications = notifications
        self.router = router
        self.errors = errors
    }

    // MARK: - Handling

    /// Returns only once the work (reminder rebuild included) is done: iOS may
    /// suspend the app as soon as the response is reported handled.
    func handle(_ intent: NotificationIntent) async {
        switch intent {
        case .openDailyReminder(let reminder):
            // On a cold launch the router parks the link until the UI is up.
            router.open(.dailyReminder(reminder))

        case .take(let ids, let slot):
            await write(ids, slot) { try self.doseLogging.markTaken($0) }

        case .skip(let ids, let slot):
            await write(ids, slot) { try self.doseLogging.markSkipped($0) }

        case .snooze(let ids, let names, let slot):
            await notifications.scheduleSnooze(for: ids, names: names, slot: slot)

        case .openDoseReminder(let ids, let slot):
            router.open(.doseReminder(medicationIds: ids, slot: slot))
        }
    }

    /// Idempotent: already taken or skipped doses are left alone.
    private func write(_ ids: [UUID], _ slot: Date,
                       _ command: ([PillDose]) throws -> DoseLogOutcome) async {
        let open = doseLogging.openDoses(medicationIds: ids, at: slot)
        guard let outcome = errors.attempt({ try command(open) }) else { return }
        await outcome.waitForReminders()
    }
}
