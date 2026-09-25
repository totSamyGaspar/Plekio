//
//  DoseLog.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

@Model
final class DoseLog {
    @Attribute(.unique) var id: UUID
    var scheduledTime: Date

    // MARK: - Storage behind `status`
    //
    // The same four columns as before — the schema is unchanged — but private:
    // they are written only by `status`'s setter, all four together, so the
    // combinations DoseStatus rules out cannot reach the store either.

    private var isTaken: Bool
    private var actualTakeTime: Date?
    private var skippedAt: Date?
    private var dispensedQuantity: Int?

    var medication: MedicationItem?

    init(scheduledTime: Date, status: DoseStatus = .pending) {
        self.id = UUID()
        self.scheduledTime = scheduledTime
        self.isTaken = false
        self.status = status
    }

    /// What the user has answered for this dose. The only way to read or
    /// change it — see DoseStatus.
    var status: DoseStatus {
        get {
            if isTaken {
                // A taken log always had its time written; the scheduled time is
                // only a floor for a record that somehow lacks one.
                return .taken(at: actualTakeTime ?? scheduledTime, dispensed: dispensedQuantity)
            }
            if let skippedAt {
                return .skipped(at: skippedAt)
            }
            return .pending
        }
        set {
            switch newValue {
            case .pending:
                isTaken = false
                actualTakeTime = nil
                skippedAt = nil
                dispensedQuantity = nil
            case .taken(let at, let dispensed):
                isTaken = true
                actualTakeTime = at
                skippedAt = nil
                dispensedQuantity = dispensed
            case .skipped(let at):
                isTaken = false
                actualTakeTime = nil
                skippedAt = at
                dispensedQuantity = nil
            }
        }
    }
}
