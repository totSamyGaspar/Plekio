//
//  ComparisonPhotoStrip.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import SwiftUI

/// The horizontal strip of every progress photo, under the comparison canvas.
struct ComparisonPhotoStrip: View {

    // MARK: - Properties

    let checkpoints: [DiaryPhotoCheckpoint]
    let beforePhotoId: UUID
    let afterPhotoId: UUID

    /// Called when the current "before" photo is tapped.
    let onOpenBeforePicker: () -> Void
    /// Called with an unselected photo tapped, to make it "after".
    let onSelectAfter: (UUID) -> Void

    @ScaledMetric(relativeTo: .caption2) private var slotBadgeSize: CGFloat = 18

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AVAILABLE PROGRESS PHOTOS (\(checkpoints.count))")
                .font(.caption2.weight(.heavy))
                .foregroundColor(.textSecondary)
                .tracking(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                // Lazy: lists every diary photo, so an HStack would decode them all up front.
                LazyHStack(spacing: 10) {
                    ForEach(checkpoints) { item in
                        thumbnail(item)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

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
            // Tapping the current "after" photo does nothing.
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
