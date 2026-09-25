//
//  AddMedicationViewModelProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 20.05.2026.
//

import SwiftUI
import Combine

// MARK: - AddMedicationViewModelProtocol

protocol AddMedicationViewModelProtocol: ObservableObject {
    var draft: MedicationDraft { get set }
    var selectedImage: UIImage? { get set }
    var showingPhotoSourceMenu: Bool { get set }

    /// Fills the draft and loads the photo. Call from `.task`, not the view's `init`.
    func startEditing(_ medication: MedicationSnapshot) async

    /// Encodes the picked photo into the draft.
    func attachPhoto(_ image: UIImage) async
    func removeImage()
}
