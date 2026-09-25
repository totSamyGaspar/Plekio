//
//  UndoLogBanner.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import SwiftUI

/// Undo banner for "Log all" / "Skip"; used instead of a confirmation dialog.
struct UndoLogBanner: View {

    // MARK: - Properties

    let kind: UndoableDoseAction.Kind
    let count: Int
    /// Window start, so a rebuilt banner shows the true time left.
    let startedAt: Date
    let duration: TimeInterval
    var onUndo: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// LocalizedStringKey per case; a String ternary would skip localization.
    private var message: LocalizedStringKey {
        switch kind {
        case .logged: "\(count) doses logged"
        case .skipped: "\(count) doses skipped"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: kind == .logged ? "checkmark.circle.fill" : "forward.end.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.accentPrimary)

                Text(message)
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

            countdownBar
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

    // MARK: - Countdown

    /// Fraction of the window left at `now`.
    private func remaining(at now: Date) -> CGFloat {
        guard duration > 0 else { return 0 }
        let left = max(0, duration - now.timeIntervalSince(startedAt))
        return CGFloat(left / duration)
    }

    /// Drawn from the clock each frame: a `withAnimation` would be absorbed by the
    /// banner's insertion spring. Hidden under Reduce Motion.
    @ViewBuilder
    private var countdownBar: some View {
        if !reduceMotion {
            TimelineView(.animation) { context in
                Capsule()
                    .fill(Color.accentPrimary.opacity(0.14))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.accentPrimary)
                            .scaleEffect(x: remaining(at: context.date), y: 1, anchor: .leading)
                    }
                    // An implicit animation would lag behind the clock.
                    .transaction { $0.animation = nil }
            }
            .accessibilityHidden(true)
        }
    }
}
