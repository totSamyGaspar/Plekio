//
//  DiaryPhotoCheckpoint.swift
//  Plekio
//
//  Created by Edward Gasparian on 24.08.2026.
//

import SwiftUI

// MARK: - DiaryPhotoCheckpoint

struct DiaryPhotoCheckpoint: Identifiable {
    /// The photo's id doubles as the checkpoint's id.
    let id: UUID
    let category: String
    let entry: DiaryEntrySnapshot

    init(photoId: UUID, entry: DiaryEntrySnapshot) {
        self.id = photoId
        self.entry = entry
        // Localized title, not the storage key; casing is applied at display time.
        self.category = DiaryMilestoneOptions.categoryTitle(for: entry.milestoneTags.first)
    }
}
