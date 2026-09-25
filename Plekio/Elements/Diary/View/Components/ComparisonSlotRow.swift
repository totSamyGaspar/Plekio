//
//  ComparisonSlotRow.swift
//  Plekio
//

import SwiftUI

extension DiaryPhotoCheckpoint {

    /// How a photo is named wherever it has to be named in the comparison screen
    /// — the two selector rows and the picker sheet. It was a private method on
    /// the screen used from all three, so the date format lived one place and the
    /// fallback another.
    static let comparisonDateStyle = Date.FormatStyle(date: .abbreviated, time: .omitted)

    var comparisonCaption: String {
        let dateText = entry.checkInDate.formatted(Self.comparisonDateStyle)
        let notes = entry.displayCaption
        return notes.isEmpty ? dateText : "\(dateText) • \(notes)"
    }

    /// The caption for a slot that may not be filled yet.
    static func caption(for checkpoint: DiaryPhotoCheckpoint?) -> String {
        // `String(localized:)`, not a bare literal: this returns a String, and a
        // plain one would reach the screen in English whatever the device language.
        checkpoint?.comparisonCaption ?? String(localized: "Select a photo")
    }
}

/// One of the two "BEFORE / AFTER" pickers above the comparison canvas.
struct ComparisonSlotRow: View {

    let label: LocalizedStringKey
    let tint: Color
    let checkpoint: DiaryPhotoCheckpoint?
    let action: () -> Void

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
