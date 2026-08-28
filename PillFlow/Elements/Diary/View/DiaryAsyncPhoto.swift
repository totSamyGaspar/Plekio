//
//  DiaryAsyncPhoto.swift
//  PillFlow
//
//  Created by Edward Gasparian on 25.08.2026.
//
//  Shared async photo loader for the Diary feature. Replaces three
//  near-identical private views that each duplicated the same "check
//  ImageCache, decode off the cache-miss path, render a placeholder while
//  loading" logic (DiaryEntryRowView's DiaryPhotoThumbnail, DiaryView's
//  DiaryPhotoBanner and ComparisonThumbnailImage). Deliberately does NOT bake
//  in a frame or corner radius — callers size and clip it themselves, the
//  same way they'd compose a plain Image, so this stays reusable across every
//  size Diary needs (68pt row thumbnails, 180pt gallery banners, 76pt
//  comparison strip tiles) instead of growing a new near-duplicate per size.
//

import SwiftUI

struct DiaryAsyncPhoto: View {
    let photoId: UUID
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.05)
            }
        }
        .task(id: photoId) {
            image = await ImageCache.shared.image(for: photoId)
        }
    }
}
