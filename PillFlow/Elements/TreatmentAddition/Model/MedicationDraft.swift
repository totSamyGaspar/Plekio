//
//  MedicationDraft.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct MedicationDraft: Identifiable, Equatable {
    var id = UUID()
    var name: String = ""
    var formSystemImage: String = "pills.fill"
    var dosage: Int = 1
    var timesOfDay: [Date] = [Date()]
    var frequencyDays: Int = 1
    var medicationImageData: Data? = nil
    /// Whether the user actually touched the photo in this editing session.
    ///
    /// `medicationImageData == nil` alone can't tell "no photo" apart from "the
    /// photo wasn't loaded yet": `init(from:)` starts empty and the bytes arrive
    /// asynchronously. Without this flag DatabaseService.updateMedication read that
    /// nil as a deletion and erased the file. Same reason as
    /// `DiaryEntryDraft.photosModified`.
    var photoModified: Bool = false
    
    var stockCount: Int = 30
    var lowStockThreshold: Int = 10
}

extension MedicationDraft {
    /// The single place MedicationItem fields are moved into the form; copying them
    /// by hand elsewhere loses one too easily — same reason as
    /// `DiaryEntryDraft.init(from:)`. The photo is not carried over: it lives on
    /// disk and is loaded off the main thread by `AddMedicationViewModel.startEditing`,
    /// which is why `photoModified` stays false here — preloading is not an edit.
    init(from medication: MedicationItem) {
        self.init(
            id: medication.id,
            name: medication.name,
            formSystemImage: medication.formSystemImage,
            dosage: medication.dosage,
            timesOfDay: medication.timesOfDay,
            frequencyDays: medication.frequencyDays,
            medicationImageData: nil,
            photoModified: false,
            stockCount: medication.stockCount,
            lowStockThreshold: medication.lowStockThreshold
        )
    }
}
