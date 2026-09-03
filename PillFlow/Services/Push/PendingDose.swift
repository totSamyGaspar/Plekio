//
//  PendingDose.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.06.2026.
//
//  Shared "dose from a notification" logic: the push's own "Take Now" button
//  and the sheet shown after tapping it must log a dose the same way.
//

import Foundation

@MainActor
enum PendingDose {

    /// Doses of the slot that are not yet marked as taken.
    ///
    /// Times are compared with a one-second tolerance: the slot time arrives from
    /// `userInfo` as a `timeIntervalSince1970` Double, so exact equality is not
    /// safe to rely on.
    static func unlogged(
        medicationIds: [UUID],
        scheduledTime: Date,
        in dbService: DatabaseServiceProtocol
    ) -> [PillDose] {
        dbService.fetchPills(for: scheduledTime, preFetchedCourses: nil)
            .filter {
                medicationIds.contains($0.medicationId)
                    && abs($0.time.timeIntervalSince(scheduledTime)) < 1
                    && !$0.isTaken
            }
    }

    /// Marks the doses as taken and rebuilds the notification schedule.
    ///
    /// Async because of the rebuild: AppDelegate has to know when this is finished
    /// before it tells iOS the notification response is handled.
    @discardableResult
    static func markTaken(
        _ pills: [PillDose],
        dbService: DatabaseServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) async -> Bool {
        guard !pills.isEmpty else { return true }

        guard AppErrorPresenter.shared.run({
            for pill in pills {
                try dbService.togglePill(medicationId: pill.medicationId, scheduledTime: pill.time)
            }
        }) else { return false }

        await notificationService.rescheduleAll(using: dbService)
        return true
    }
}
