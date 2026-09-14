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
        in dbService: any CourseStoring & DoseStoring
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
    ///
    /// Idempotent on its own: `markDosesTaken` leaves an already-logged dose alone,
    /// so a second press of "Take Now" changes nothing.
    @discardableResult
    static func markTaken(
        _ pills: [PillDose],
        dbService: any CourseStoring & DoseStoring,
        notificationService: NotificationServiceProtocol
    ) async -> Bool {
        guard !pills.isEmpty else { return true }

        guard AppErrorPresenter.shared.run({
            for (slot, doses) in Dictionary(grouping: pills, by: \.time) {
                try dbService.markDosesTaken(
                    medicationIds: doses.map(\.medicationId),
                    scheduledTime: slot
                )
            }
        }) else { return false }

        await notificationService.rescheduleAll(using: dbService)
        return true
    }

    // MARK: - Skip

    /// Writes the skip and returns the slots it touched, or nil if the write
    /// failed. Split from the notification half so a view model can show the new
    /// state immediately and do the rebuild behind it, the way logging does.
    static func recordSkip(
        _ pills: [PillDose],
        dbService: any CourseStoring & DoseStoring
    ) -> [Date: [PillDose]]? {
        // A dose already taken is not skippable, and one already skipped would
        // only have its timestamp moved.
        let open = pills.filter { !$0.isTaken && !$0.isSkipped }
        guard !open.isEmpty else { return [:] }

        let bySlot = Dictionary(grouping: open, by: \.time)

        guard AppErrorPresenter.shared.run({
            for (slot, doses) in bySlot {
                try dbService.skipDoses(medicationIds: doses.map(\.medicationId), scheduledTime: slot)
            }
        }) else { return nil }

        return bySlot
    }

    /// Rebuilds the schedule after a skip and clears the lock screen.
    ///
    /// The rebuild is what keeps a skip local to its own occurrence. Cancelling by
    /// medication instead would strip every pending request naming that id, so
    /// skipping tonight would take tomorrow morning with it — and every morning
    /// after, until something else triggered a rebuild. Instead
    /// the skip is written down, `buildScheduleMap` treats a skipped slot like a
    /// taken one, and the rebuild puts every other slot back.
    static func refreshAfterSkip(
        slots: [Date],
        dbService: any CourseStoring & DoseStoring,
        notificationService: NotificationServiceProtocol
    ) async {
        await notificationService.rescheduleAll(using: dbService)

        for slot in slots {
            // Read back rather than reusing what was just skipped: the banner may
            // only come down once every medication in the group is answered for,
            // and some of them may have been taken earlier.
            let settled = dbService.fetchPills(for: slot, preFetchedCourses: nil)
                .filter { abs($0.time.timeIntervalSince(slot)) < 1 && ($0.isTaken || $0.isSkipped) }
                .map(\.medicationId)

            guard !settled.isEmpty else { continue }
            await notificationService.clearDelivered(settledMedicationIds: settled, scheduledTime: slot)
        }
    }

    /// Both halves, for callers with no UI to refresh — the notification action
    /// button and the push-launched sheet.
    @discardableResult
    static func markSkipped(
        _ pills: [PillDose],
        dbService: any CourseStoring & DoseStoring,
        notificationService: NotificationServiceProtocol
    ) async -> Bool {
        guard let bySlot = recordSkip(pills, dbService: dbService) else { return false }
        guard !bySlot.isEmpty else { return true }

        await refreshAfterSkip(
            slots: Array(bySlot.keys),
            dbService: dbService,
            notificationService: notificationService
        )
        return true
    }
}
