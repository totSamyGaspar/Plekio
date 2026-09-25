//
//  DiaryAsyncPhoto.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.08.2026.
//

import SwiftUI

/// A diary photo loaded asynchronously, with a placeholder until it arrives.
struct DiaryAsyncPhoto: View {

    // MARK: - Properties

    @Environment(\.imageLoader) private var imageLoader
    let photoId: UUID

    /// Longest drawn edge in points; the photo is decoded at this size.
    /// No default on purpose, so a thumbnail can't silently decode a full-size photo.
    let targetPointSize: CGFloat

    @State private var image: UIImage?

    // MARK: - Body

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.textPrimary.opacity(0.05)
            }
        }
        .task(id: photoId) {
            image = await imageLoader.image(for: photoId, targetPointSize: targetPointSize)
        }
    }
}
