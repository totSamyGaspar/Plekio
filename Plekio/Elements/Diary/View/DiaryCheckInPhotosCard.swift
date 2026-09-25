//
//  DiaryCheckInPhotosCard.swift
//  Plekio
//

import SwiftUI

/// Progress photos: one row holding the button that adds them and the ones
/// already added. Takes the images and what to do with them, not the view model.
///
/// It used to be a dashed rectangle reading "Click or drag photos here", with
/// the thumbnails stacked underneath. That is a web upload zone: a phone has
/// nothing to click and nothing to drag onto, the list of accepted formats
/// answers a question nobody picking from their camera roll is asking, and the
/// placeholder stayed on screen after the photos arrived, pushing the actual
/// content below it. A row that starts with an add tile is the iOS idiom, and
/// it is half the height.
struct DiaryPhotosCard: View {

    let images: [UIImage]
    @Binding var showingSourceMenu: Bool
    let onRemove: (Int) -> Void
    let onPick: (MediaSource) -> Void

    private let tile: CGFloat = 88

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading
            row
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

            // Only once there is something to count. A chip reading "0" is a
            // label for an absence, and the empty row already says as much.
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
                        // The padding is the touch target: 24 plus 10 a side
                        // makes the 44 points HIG asks for, and it grows inwards
                        // over the photo rather than outwards into the gap,
                        // where it would collide with the next thumbnail.
                        .padding(10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove photo")
            }
    }
}

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
