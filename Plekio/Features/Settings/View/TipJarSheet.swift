//
//  TipJarSheet.swift
//  Plekio
//
//  Created by Edward Gasparian on 01.10.2026.
//

import SwiftUI

/// The tips as three cards: coffee, lunch, dinner. A tap selects a card (lunch
/// to start, so one tap pays); the button below pays for the selected one. Closes
/// once a tip is sent or waiting for approval; stays open on cancel.
struct TipJarSheet: View {

    let options: [TipOption]
    /// Runs the purchase; true when the sheet should close.
    let give: (TipSize) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selected: TipSize = .medium
    @State private var isGiving = false

    var body: some View {
        VStack(spacing: 20) {
            AppLogo(size: 52)
                .padding(.top, 12)

            VStack(spacing: 8) {
                Text("Support the project")
                    .scaledFont(size: 24, relativeTo: .title2, weight: .bold, design: .serif)
                    .foregroundColor(.textPrimary)

                Text("Plekio is free and has no ads. If it helps you, you can leave a tip.")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                ForEach(options) { option in
                    card(option)
                }
            }

            Spacer(minLength: 0)

            payButton
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
        // Large stays available for big Dynamic Type sizes.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isGiving)
        .appTheme()
    }

    // MARK: - Card

    private func card(_ option: TipOption) -> some View {
        let isSelected = option.tip == selected

        return Button {
            withMotion { selected = option.tip }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: option.tip.systemImage)
                    .font(.system(size: 22))
                    .foregroundColor(.accentPrimary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.accentPrimary.opacity(isSelected ? 0.22 : 0.12)))

                Text(option.tip.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(verbatim: option.displayPrice)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundColor(isSelected ? .accentPrimary : .textSecondary)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.appSurface)
            .clipShape(.rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.accentPrimary : Color.textPrimary.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.95))
        .disabled(isGiving)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Pay

    private var payButton: some View {
        let price = options.first { $0.tip == selected }?.displayPrice ?? ""

        return Button {
            Task { await pay() }
        } label: {
            if isGiving {
                ProgressView().tint(.onAccent)
            } else {
                Text("Leave a tip") + Text(verbatim: " · \(price)")
            }
        }
        .buttonStyle(OnboardingButtonStyle())
        .disabled(isGiving)
    }

    private func pay() async {
        isGiving = true
        let shouldClose = await give(selected)
        isGiving = false
        if shouldClose { dismiss() }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    Color.appBackground
        .sheet(isPresented: .constant(true)) {
            TipJarSheet(
                options: [
                    TipOption(tip: .small, displayPrice: "$0.99"),
                    TipOption(tip: .medium, displayPrice: "$4.99"),
                    TipOption(tip: .large, displayPrice: "$9.99"),
                ],
                give: { _ in true }
            )
        }
}
#endif
