//
//  EmptyStateView.swift
//  PillFlow
//
//  Shared empty state. Nearly the same "icon + caption" block existed in
//  three copies — DashboardView, DiaryView and CoursesListView.
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

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        EmptyStateView(icon: "pills", title: "Nothing for today")
    }
}
