//
//  DiaryCheckInPhotosCard.swift
//  PillFlow
//

import SwiftUI

/// Progress photos: the drop area, the attached thumbnails, and the source
/// picker. Takes the images and what to do with them, not the view model.
struct DiaryPhotosCard: View {
    let images: [UIImage]
    @Binding var showingSourceMenu: Bool
    let onRemove: (Int) -> Void
    let onPick: (MediaSource) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading
            dropArea
            if !images.isEmpty { thumbnails }
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(18)
        .confirmationDialog("Add Photo", isPresented: $showingSourceMenu, titleVisibility: .visible) {
            Button("Take Photo (Camera)") { onPick(.camera) }
            Button("Choose from Library") { onPick(.photoLibrary) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var heading: some View {
        HStack(alignment: .top) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "camera.fill")
                    .foregroundColor(.accentPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progress Photos Tracking")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.textPrimary)
                    Text("Add photos to track skin changes, body posture, wellness milestones or recovery progress")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
            }
            Spacer()
            Text("\(images.count) Attached")
                .font(.caption2.weight(.bold))
                .foregroundColor(.accentPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentPrimary.opacity(0.12))
                .cornerRadius(8)
        }
    }

    private var dropArea: some View {
        Button {
            showingSourceMenu = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(.textTertiary)
                Text("Click or drag photos here")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.textSecondary)
                Text("Supports mobile camera snapshots & image gallery (JPG, PNG, WebP)")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundColor(.textPrimary.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }

    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        // The thumbnail itself has no tap action, so the 44pt
                        // target can grow inward over the photo: the glyph stays
                        // pinned in the corner where it was and there is nothing
                        // underneath to hit by mistake.
                        Button {
                            withAnimation { onRemove(index) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .frame(width: 44, height: 44, alignment: .topTrailing)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Remove photo")
                        .padding(4)
                    }
                }
            }
        }
    }
}
