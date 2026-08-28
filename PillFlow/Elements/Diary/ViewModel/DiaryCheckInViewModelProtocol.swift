//
//  DiaryCheckInViewModelProtocol.swift
//  PillFlow
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

    func requestImageSelection(source: MediaSource)
    func removePhoto(at index: Int)

    /// Switches the form into editing an existing entry: fills the draft and
    /// loads its photos from disk. Called from the view's `.task`, not its
    /// `init` — SwiftUI re-runs view initializers many times over.
    func startEditing(_ entry: DiaryEntry) async

    /// Returns false when the save failed, so the form stays open.
    @discardableResult
    func save() -> Bool
}
