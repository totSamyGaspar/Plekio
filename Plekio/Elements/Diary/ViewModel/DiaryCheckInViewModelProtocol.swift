//
//  DiaryCheckInViewModelProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 24.08.2026.
//

import SwiftUI
import Combine

@MainActor
protocol DiaryCheckInViewModelProtocol: ObservableObject {
    var draft: DiaryEntryDraft { get set }
    var selectedImages: [UIImage] { get set }
    var showingPhotoSourceMenu: Bool { get set }
    
    func toggleSymptom(_ symptom: String)
    func addCustomSymptom(_ symptom: String)
    func toggleMilestone(_ tag: String)
    func addCustomMilestone(_ tag: String)
    
    /// Whether a chip is on. Paired with the toggles above on purpose: asked by
    /// reaching into `draft.symptoms.contains(_:)` from the view instead, a change
    /// in how selection is stored breaks reading silently while toggling keeps
    /// working.
    func isSymptomSelected(_ symptom: String) -> Bool
    func isMilestoneSelected(_ tag: String) -> Bool
    
    /// Encodes the picked photo into the draft.
    func attachPhoto(_ image: UIImage) async
    func removePhoto(at index: Int)
    
    /// Switches the form into editing an existing entry: fills the draft and
    /// loads its photos from disk. Called from the view's `.task`, not its
    /// `init` — SwiftUI re-runs view initializers many times over.
    func startEditing(_ entry: DiaryEntrySnapshot) async
    
    /// Returns false when the save failed, so the form stays open.
    @discardableResult
    func save() -> Bool
}

extension DiaryCheckInViewModelProtocol {
    
    // Both conformers store selection the same way, so the answer lives once
    // here rather than being written out in the view model and again in the mock.
    func isSymptomSelected(_ symptom: String) -> Bool {
        draft.symptoms.contains(symptom)
    }
    
    func isMilestoneSelected(_ tag: String) -> Bool {
        draft.milestoneTags.contains(tag)
    }
}
