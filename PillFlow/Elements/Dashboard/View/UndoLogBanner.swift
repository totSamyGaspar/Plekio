//
//  UndoLogBanner.swift
//  PillFlow
//

import SwiftUI

/// The way back from a mistapped "Log all".
///
/// A banner rather than a confirmation dialog: the correct path — the user did
/// mean to log the doses — stays a single tap, and only the mistake costs a
/// second one.
struct UndoLogBanner: View {
    let count: Int
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundColor(.accentPrimary)

            Text("\(count) doses logged")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Button(action: onUndo) {
                Text("Undo")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.accentPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.accentPrimary.opacity(0.14))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: Color.appShadow, radius: 14, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.textPrimary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}
