//
//  DiaryCheckInPhotosCard.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.09.2026.
//

import SwiftUI

/// Progress photos: an add tile followed by the photos already added.
struct DiaryPhotosCard: View {

    // MARK: - Properties

    let images: [UIImage]
    @Binding var showingSourceMenu: Bool
    let onRemove: (Int) -> Void
    let onPick: (UIImage) -> Void

    private let tile: CGFloat = 88

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading
            row
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(18)
        .photoSourceDialog("Add Photo", isPresented: $showingSourceMenu, onPick: onPick)
    }

    // MARK: - Heading

    private var heading: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "camera.fill")
                .foregroundColor(.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Progress photos")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.textPrimary)

                Text("Add photos to track skin changes, body posture, wellness milestones or recovery progress")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }

            Spacer(minLength: 8)

            // Hidden at zero: the empty row already says there are none.
            if !images.isEmpty {
                Text("\(images.count) Attached")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.accentPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentPrimary.opacity(0.12))
                    .cornerRadius(8)
                    .fixedSize()
            }
        }
    }

    // MARK: - Row

    private var row: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                addTile
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    thumbnail(image, at: index)
                }
            }
        }
    }

    private var addTile: some View {
        Button {
            showingSourceMenu = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                Text("Add")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundColor(.accentPrimary)
            .frame(width: tile, height: tile)
            .background(Color.accentPrimary.opacity(0.12))
            .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add Photo")
    }

    private func thumbnail(_ image: UIImage, at index: Int) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: tile, height: tile)
            .clipShape(.rect(cornerRadius: 16))
            .accessibilityLabel("Diary photo")
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation { onRemove(index) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                        // 24 + 10 a side = 44pt touch target, growing inward so it can't overlap the next thumbnail.
                        .padding(10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove photo")
            }
    }
}

// MARK: - Preview

#Preview {
    DiaryPhotosCard(
        images: [],
        showingSourceMenu: .constant(false),
        onRemove: { _ in },
        onPick: { _ in }
    )
    .padding()
    .background(Color.appBackground)
}
