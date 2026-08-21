//
//  AddMedicationViewModelProtocol.swift
//  PillFlow
//
//  Created by Edward Gasparian on 20.05.2026.
//

import SwiftUI
import Combine

protocol AddMedicationViewModelProtocol: ObservableObject {
    var draft: MedicationDraft { get set }
    var selectedImage: UIImage? { get set }
    var showingPhotoSourceMenu: Bool { get set }
    
    func requestImageSelection(source: MediaSource)
    func removeImage()
}
