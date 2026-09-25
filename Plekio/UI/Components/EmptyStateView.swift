//
//  EmptyStateView.swift
//  Plekio
//
//  Created by Edward Gasparian on 28.08.2026.
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    var verticalPadding: CGFloat = 50

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .scaledFont(size: 46, relativeTo: .largeTitle)
                .foregroundColor(.textPrimary.opacity(0.2))

            Text(title)
                .font(.headline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        EmptyStateView(icon: "pills", title: "Nothing for today")
    }
}
