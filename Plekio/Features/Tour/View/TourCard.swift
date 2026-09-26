//
//  TourCard.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

/// The step's title, text and Skip / Next controls.
struct TourCard: View {

    // MARK: - Properties

    let step: TourStep
    let onNext: () -> Void
    let onSkip: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(step.title)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer(minLength: 8)
                Text("\(step.rawValue + 1) of \(TourStep.allCases.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.textSecondary)
                    .monospacedDigit()
            }

            Text(step.message)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Skip", action: onSkip)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.textSecondary)

                Spacer()

                if step.waitsForAction {
                    Label("Tap the highlighted button", systemImage: "hand.tap")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accentPrimary)
                } else {
                    Button(action: onNext) {
                        Text(step.isLast ? "Got it" : "Next")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.onAccent)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.accentPrimary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        )
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .id(step)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}
