//
//  AddMedicationViewModelProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 20.05.2026.
//

import SwiftUI
import Combine

protocol AddMedicationViewModelProtocol: ObservableObject {
    var draft: MedicationDraft { get set }
    var selectedImage: UIImage? { get set }
    var showingPhotoSourceMenu: Bool { get set }
    
    /// Switches the form into edit mode: fills the draft and loads the photo from
    /// disk. Called from the view's `.task`, not its `init`.
    func startEditing(_ medication: MedicationSnapshot) async

    /// Encodes the picked photo into the draft.
    func attachPhoto(_ image: UIImage) async
    func removeImage()
}
