//
//  MedicationDraft.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct MedicationDraft: Identifiable, Equatable {
    var id = UUID()
    var name: String = ""
    var form: MedicationForm = .pill
    var dosage: Int = 1
    var minutesOfDay: [Int] = [MinuteOfDay.of(Date(), calendar: .current)]
    var frequencyDays: Int = 1
    var medicationImageData: Data? = nil
    /// Whether the user changed the photo. A nil `medicationImageData` may just mean
    /// "not loaded yet", so only this flag permits deleting the stored photo.
    var photoModified: Bool = false

    var stockCount: Int = 30
    var lowStockThreshold: Int = 10
}

// MARK: - Snapshot Conversion

extension MedicationDraft {
    /// The only place snapshot fields are copied into a draft. The photo is loaded
    /// separately by `AddMedicationViewModel.startEditing`; preloading is not an edit.
    init(from medication: MedicationSnapshot) {
        self.init(
            id: medication.id,
            name: medication.name,
            form: medication.form,
            dosage: medication.dosage,
            minutesOfDay: medication.minutesOfDay,
            frequencyDays: medication.frequencyDays,
            medicationImageData: nil,
            photoModified: false,
            stockCount: medication.stockCount,
            lowStockThreshold: medication.lowStockThreshold
        )
    }
}
