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

    func save()
}
