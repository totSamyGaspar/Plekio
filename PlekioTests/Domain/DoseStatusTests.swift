//
//  DoseStatusTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DoseStatus")
struct DoseStatusTests {

    // MARK: - Helpers

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Moves

    @Test("Both pending and skipped doses can be taken, but not an already taken one")
    func takingOverridesASkipButNotATake() {
        #expect(DoseStatus.pending.taking(at: now, dispensed: 1) == .taken(at: now, dispensed: 1))
        #expect(DoseStatus.skipped(at: now).taking(at: now, dispensed: 1) == .taken(at: now, dispensed: 1))
        #expect(DoseStatus.taken(at: now, dispensed: 1).taking(at: now, dispensed: 1) == nil)
    }

    @Test("A taken dose can't be skipped")
    func takenDoseCannotBeSkipped() {
        #expect(DoseStatus.pending.skipping(at: now) == .skipped(at: now))
        #expect(DoseStatus.taken(at: now, dispensed: 1).skipping(at: now) == nil)
    }

    @Test("Undo restores exactly what left the stock, and only for a taken dose")
    func revertingCreditsExactlyWhatWentOut() {
        let reverted = DoseStatus.taken(at: now, dispensed: 0).reverting()
        #expect(reverted?.status == .pending)
        // An empty bottle gave nothing, so nothing comes back.
        #expect(reverted?.credit == 0)

        #expect(DoseStatus.pending.reverting() == nil)
        #expect(DoseStatus.skipped(at: now).reverting() == nil)
    }

    @Test("Only a skip can be undone")
    func unskippingOnlyMovesASkip() {
        #expect(DoseStatus.skipped(at: now).unskipping() == .pending)
        #expect(DoseStatus.pending.unskipping() == nil)
        #expect(DoseStatus.taken(at: now, dispensed: 1).unskipping() == nil)
    }

    @Test("isSettled: taken and skipped yes, pending no")
    func settledCoversTakenAndSkipped() {
        #expect(DoseStatus.taken(at: now, dispensed: 1).isSettled)
        #expect(DoseStatus.skipped(at: now).isSettled)
        #expect(!DoseStatus.pending.isSettled)
    }

    // MARK: - Storage

    @Test("DoseLog reads back exactly the status written to it")
    func doseLogRoundTripsEveryStatus() {
        let log = DoseLog(scheduledTime: now)
        #expect(log.status == .pending)

        for status in [DoseStatus.taken(at: now, dispensed: 2), .skipped(at: now), .pending, .taken(at: now, dispensed: nil)] {
            log.status = status
            #expect(log.status == status)
        }
    }

    @Test("Going from skipped to taken leaves no trace of the skip")
    func noFieldSurvivesAChangeOfState() {
        let log = DoseLog(scheduledTime: now, status: .skipped(at: now))

        log.status = .taken(at: now, dispensed: 1)
        #expect(!log.status.isSkipped)

        log.status = .pending
        #expect(log.status.dispensed == nil)
        #expect(log.status.takenAt == nil)
    }
}
