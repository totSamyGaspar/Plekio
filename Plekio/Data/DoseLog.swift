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
    var actualTakeTime: Date?
    var isTaken: Bool
    /// When the user deliberately passed on this dose.
    ///
    /// Nil covers both "still due" and "never logged", because those two are the
    /// same thing to every reader. A skip is not: "decided against it" and
    /// "forgot" produce identical rows otherwise, and the schedule rebuild has to
    /// tell them apart — an untaken slot gets its reminder back, a skipped one
    /// must not. Optional with an implicit nil, so the store migrates in place.
    var skippedAt: Date?
    
    /// How many units actually left the stock when this dose was logged.
    ///
    /// Not the same as the medication's dosage. Stock is clamped at zero, so a
    /// dose logged with a nearly empty bottle takes out less than a full dose —
    /// sometimes nothing at all. Crediting back a full dosage on undo would invent
    /// pills that were never there: log a dose at zero stock, undo it, and the
    /// bottle has refilled itself.
    ///
    /// Nil means this dose is not currently logged as taken, or predates the
    /// field. It is also what makes an edit to the dosage safe after the fact:
    /// what comes back is what went out, not what a dose happens to be today.
    var dispensedQuantity: Int?
    
    
    var medication: MedicationItem?
    
    init(scheduledTime: Date, isTaken: Bool) {
        self.id = UUID()
        self.scheduledTime = scheduledTime
        self.isTaken = isTaken
    }
}
