//
//  DoseStatusTests.swift
//  PlekioTests
//
//  The moves between dose states, and that DoseLog stores whatever status it
//  is given without leaving a field from the previous one behind.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("DoseStatus")
struct DoseStatusTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Moves

    @Test("принять можно и ожидающую, и пропущенную дозу, но не уже принятую")
    func takingOverridesASkipButNotATake() {
        #expect(DoseStatus.pending.taking(at: now, dispensed: 1) == .taken(at: now, dispensed: 1))
        #expect(DoseStatus.skipped(at: now).taking(at: now, dispensed: 1) == .taken(at: now, dispensed: 1))
        #expect(DoseStatus.taken(at: now, dispensed: 1).taking(at: now, dispensed: 1) == nil)
    }

    @Test("принятую дозу пропустить нельзя")
    func takenDoseCannotBeSkipped() {
        #expect(DoseStatus.pending.skipping(at: now) == .skipped(at: now))
        #expect(DoseStatus.taken(at: now, dispensed: 1).skipping(at: now) == nil)
    }

    @Test("отмена возвращает ровно то, что ушло со склада, и только для принятой")
    func revertingCreditsExactlyWhatWentOut() {
        let reverted = DoseStatus.taken(at: now, dispensed: 0).reverting()
        #expect(reverted?.status == .pending)
        // An empty bottle gave nothing, so nothing comes back.
        #expect(reverted?.credit == 0)

        #expect(DoseStatus.pending.reverting() == nil)
        #expect(DoseStatus.skipped(at: now).reverting() == nil)
    }

    @Test("isSettled: принятая и пропущенная — да, ожидающая — нет")
    func settledCoversTakenAndSkipped() {
        #expect(DoseStatus.taken(at: now, dispensed: 1).isSettled)
        #expect(DoseStatus.skipped(at: now).isSettled)
        #expect(!DoseStatus.pending.isSettled)
    }

    // MARK: - Storage

    @Test("DoseLog читает обратно ровно тот статус, что в него записали")
    func doseLogRoundTripsEveryStatus() {
        let log = DoseLog(scheduledTime: now)
        #expect(log.status == .pending)

        for status in [DoseStatus.taken(at: now, dispensed: 2), .skipped(at: now), .pending, .taken(at: now, dispensed: nil)] {
            log.status = status
            #expect(log.status == status)
        }
    }

    @Test("переход из пропущенной в принятую не оставляет следов пропуска")
    func noFieldSurvivesAChangeOfState() {
        let log = DoseLog(scheduledTime: now, status: .skipped(at: now))

        log.status = .taken(at: now, dispensed: 1)
        #expect(!log.status.isSkipped)

        log.status = .pending
        #expect(log.status.dispensed == nil)
        #expect(log.status.takenAt == nil)
    }
}
