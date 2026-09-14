//
//  ComparisonPhotoStrip.swift
//  PillFlow
//

import SwiftUI

/// The horizontal strip of every progress photo, under the comparison canvas.
///
/// Takes the two chosen ids and reports taps back; it holds no state of its own,
/// which is what made it separable from the screen around it.
struct ComparisonPhotoStrip: View {

    let checkpoints: [DiaryPhotoCheckpoint]
    let beforePhotoId: UUID
    let afterPhotoId: UUID

    /// Tapping the photo that is already "before" opens its picker, so the tap is
    /// never dead.
    let onOpenBeforePicker: () -> Void
    /// Tapping any other un-selected photo quick-assigns it as "after".
    let onSelectAfter: (UUID) -> Void

    @ScaledMetric(relativeTo: .caption2) private var slotBadgeSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AVAILABLE PROGRESS PHOTOS (\(checkpoints.count))")
                .font(.caption2.weight(.heavy))
                .foregroundColor(.textSecondary)
                .tracking(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                // Lazy: this strip lists every photo across the whole diary, not
                // just the current gallery filter — with a long history a plain
                // HStack would decode every thumbnail up front.
                LazyHStack(spacing: 10) {
                    ForEach(checkpoints) { item in
                        thumbnail(item)
                    }
                }
            }
        }
    }

    private func thumbnail(_ item: DiaryPhotoCheckpoint) -> some View {
        let isBefore = item.id == beforePhotoId
        let isAfter = item.id == afterPhotoId

        return VStack(spacing: 4) {
            DiaryAsyncPhoto(photoId: item.id, targetPointSize: 76)
                .frame(width: 76, height: 76)
                .clipped()
                .cornerRadius(12)
                .overlay(alignment: .topLeading) {
                    if isBefore { badge("A", tint: .accentPrimary) }
                }
                .overlay(alignment: .topTrailing) {
                    if isAfter { badge("B", tint: .warmAccent) }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((isBefore || isAfter) ? Color.accentPrimary.opacity(0.8) : Color.clear, lineWidth: 2)
                )

            Text(item.entry.checkInDate.formatted(DiaryPhotoCheckpoint.comparisonDateStyle))
                .font(.caption2)
                .foregroundColor(.textSecondary)
        }
        .onTapGesture {
            // Tapping the current "after" photo is the one no-op: it is already
            // selected, and there is nothing sensible to change it to.
            if isBefore {
                onOpenBeforePicker()
            } else if !isAfter {
                onSelectAfter(item.id)
            }
        }
    }

    private func badge(_ letter: String, tint: Color) -> some View {
        Text(letter)
            .font(.caption2.weight(.heavy))
            .foregroundColor(Color.onAccent)
            .frame(width: slotBadgeSize, height: slotBadgeSize)
            .background(tint)
            .clipShape(Circle())
            .padding(4)
    }
}
