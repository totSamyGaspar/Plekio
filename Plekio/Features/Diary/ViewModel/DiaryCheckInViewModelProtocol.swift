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

    /// Whether a chip is on. Views ask this instead of reading `draft` directly.
    func isSymptomSelected(_ symptom: String) -> Bool
    func isMilestoneSelected(_ tag: String) -> Bool

    /// Encodes the picked photo into the draft.
    func attachPhoto(_ image: UIImage) async
    func removePhoto(at index: Int)

    /// Fills the draft from an existing entry and loads its photos. Call from
    /// `.task`, not the view's `init`, which SwiftUI re-runs many times.
    func startEditing(_ entry: DiaryEntrySnapshot) async

    /// Returns false when the save failed, so the form stays open.
    @discardableResult
    func save() -> Bool
}

// MARK: - Selection

extension DiaryCheckInViewModelProtocol {

    func isSymptomSelected(_ symptom: String) -> Bool {
        draft.symptoms.contains(symptom)
    }

    func isMilestoneSelected(_ tag: String) -> Bool {
        draft.milestoneTags.contains(tag)
    }
}
