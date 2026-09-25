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

    // MARK: - Properties

    @Attribute(.unique) var id: UUID
    var scheduledTime: Date

    // MARK: - Storage Behind Status

    // Schema columns; written only together by `status`'s setter, so invalid
    // combinations never reach the store.
    private var isTaken: Bool
    private var actualTakeTime: Date?
    private var skippedAt: Date?
    private var dispensedQuantity: Int?

    var medication: MedicationItem?

    // MARK: - Init

    init(scheduledTime: Date, status: DoseStatus = .pending) {
        self.id = UUID()
        self.scheduledTime = scheduledTime
        self.isTaken = false
        self.status = status
    }

    // MARK: - Status

    /// The only way to read or change the dose's state.
    var status: DoseStatus {
        get {
            if isTaken {
                // Scheduled time is only a fallback for a record missing its take time.
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
