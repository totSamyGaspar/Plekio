//
//  EmptyStateView.swift
//  Plekio
//
//  Created by Edward Gasparian on 28.08.2026.
//

import SwiftUI

struct EmptyStateView: View {

    // MARK: - Properties

    let icon: String
    let title: LocalizedStringKey
    var verticalPadding: CGFloat = 50
    /// Optional call to action under the title.
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .scaledFont(size: 46, relativeTo: .largeTitle)
                .foregroundColor(.textPrimary.opacity(0.2))

            Text(title)
                .font(.headline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.onAccent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.accentPrimary))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        EmptyStateView(icon: "pills", title: "Nothing for today")
    }
}
#endif
