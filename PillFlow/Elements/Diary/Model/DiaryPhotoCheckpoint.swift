//
//  DiaryPhotoCheckpoint.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//
//  One progress photo together with the entry it came from: the gallery
//  treats every photo as a checkpoint, not every diary entry.
//
//  The category is derived here rather than in a view, so the gallery and the
//  comparison screen cannot disagree about it.
//

import SwiftUI

struct DiaryPhotoCheckpoint: Identifiable {
    /// The photo's id doubles as the checkpoint's id.
    let id: UUID
    let category: String
    let entry: DiaryEntry

    init(photoId: UUID, entry: DiaryEntry) {
        self.id = photoId
        self.entry = entry
        // The localized milestone title, not its storage key. Uppercasing and
        // underscores belong to display (.textCase): baked into the string they
        // mangle translations.
        self.category = DiaryMilestoneOptions.categoryTitle(for: entry.milestoneTags.first)
    }
}
