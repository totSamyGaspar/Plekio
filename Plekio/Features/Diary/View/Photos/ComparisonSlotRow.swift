//
//  ComparisonSlotRow.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import SwiftUI

// MARK: - DiaryPhotoCheckpoint Captions

extension DiaryPhotoCheckpoint {

    /// Date format used for photos throughout the comparison screen.
    static let comparisonDateStyle = Date.FormatStyle(date: .abbreviated, time: .omitted)

    var comparisonCaption: String {
        let dateText = entry.checkInDate.formatted(Self.comparisonDateStyle)
        let notes = entry.displayCaption
        return notes.isEmpty ? dateText : "\(dateText) • \(notes)"
    }

    /// The caption for a slot that may not be filled yet.
    static func caption(for checkpoint: DiaryPhotoCheckpoint?) -> String {
        // `String(localized:)`: a plain String literal would never be translated.
        checkpoint?.comparisonCaption ?? String(localized: "Select a photo")
    }
}

// MARK: - ComparisonSlotRow

/// One of the two "BEFORE / AFTER" pickers above the comparison canvas.
struct ComparisonSlotRow: View {

    // MARK: - Properties

    let label: LocalizedStringKey
    let tint: Color
    let checkpoint: DiaryPhotoCheckpoint?
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption2.weight(.heavy))
                .foregroundColor(tint)
                .frame(width: 96, alignment: .leading)

            Button(action: action) {
                HStack {
                    Text(DiaryPhotoCheckpoint.caption(for: checkpoint))
                        .font(.caption)
                        .foregroundColor(.textPrimary.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.appSurface)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
}
