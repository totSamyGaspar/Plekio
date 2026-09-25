//
//  OnboardingPageView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

/// A slide: a miniature of the real interface over a glow, plus title and description.
struct OnboardingPageView: View {

    // MARK: - Properties

    let page: OnboardingPage

    /// Whether this slide is on screen. `TabView` pre-builds neighbours, so
    /// `onAppear` can't be used to start the scripts.
    var isActive = true

    @State private var isGlowing = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.glow.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 165
                        )
                    )
                    .frame(width: 330, height: 330)
                    .scaleEffect(isGlowing ? 1.06 : 0.94)

                preview
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Text(page.title)
                    .scaledFont(size: 28, relativeTo: .title, weight: .bold, design: .serif)
                    .foregroundColor(.textPrimary)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .lineSpacing(3)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 34)
        }
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var preview: some View {
        switch page.preview {
        case .course: CoursePreview(isActive: isActive)
        case .day: DayPreview(isActive: isActive)
        case .reminder: ReminderPreview(isActive: isActive)
        case .diary: DiaryPreview(isActive: isActive)
        case .report: ReportPreview(isActive: isActive)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingPageView(page: OnboardingViewModel.allPages[2])
    }
}
