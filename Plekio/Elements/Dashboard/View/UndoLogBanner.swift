//
//  UndoLogBanner.swift
//  Plekio
//

import SwiftUI

/// The way back from a mistapped "Log all" or "Skip".
///
/// A banner rather than a confirmation dialog: the correct path — the user did
/// mean to log the doses — stays a single tap, and only the mistake costs a
/// second one.
struct UndoLogBanner: View {
    let kind: UndoableDoseAction.Kind
    let count: Int
    /// When the undo window opened, so the bar below shows what is actually left
    /// of it rather than restarting whenever this view is rebuilt.
    let startedAt: Date
    let duration: TimeInterval
    var onUndo: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A LocalizedStringKey per case, so both lines go through the string
    /// catalog — a ternary of two literals would decay to an unlocalized String.
    private var message: LocalizedStringKey {
        switch kind {
        case .logged: "\(count) doses logged"
        case .skipped: "\(count) doses skipped"
        }
    }

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

    /// How much of the window is left, as a fraction, at a given moment.
    private func remaining(at now: Date) -> CGFloat {
        guard duration > 0 else { return 0 }
        let left = max(0, duration - now.timeIntervalSince(startedAt))
        return CGFloat(left / duration)
    }

    /// Redrawn from the clock each frame rather than animated from 1 to 0.
    ///
    /// An explicit `withAnimation` here loses to the transaction the banner is
    /// inserted in — it slides up under a spring — and the ten seconds collapse
    /// into that spring's third of a second. A bar that is a function of the time
    /// left has no animation to hijack, and it is also self-correcting: rebuilt
    /// mid-window it draws where the deadline actually is.
    ///
    /// Dropped entirely under Reduce Motion: a bar frozen at full that then
    /// disappears says less than no bar at all.
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
                    // The width already says where the deadline is; an implicit
                    // animation on top would lag behind it.
                    .transaction { $0.animation = nil }
            }
            .accessibilityHidden(true)
        }
    }
}
