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

    var isWide = false
    var isLarge = false

    @State private var isGlowing = false

    // MARK: - Body

    var body: some View {
        Group {
            if isWide {
                HStack(spacing: 40) {
                    illustration
                    text(alignment: .leading)
                        .frame(maxWidth: isLarge ? 480 : 380, alignment: .leading)
                }
                .padding(.horizontal, 40)
            } else {
                VStack(spacing: 24) {
                    illustration
                    text(alignment: .center)
                        .frame(maxWidth: OnboardingLayout.textMaxWidth)
                        .padding(.horizontal, 34)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .onAppear {
            withMotion(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }

    // MARK: - Subviews

    private var illustration: some View {
        ScaledToFit(maxScale: isLarge ? 1.6 : 1) {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Laid out first, so the description is never cut.
    private func text(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 12) {
            Text(page.title)
                .scaledFont(size: isLarge ? 36 : 28, relativeTo: .title, weight: .bold, design: .serif)
                .foregroundColor(.textPrimary)

            Text(page.description)
                .font(isLarge ? .title3 : .body)
                .foregroundColor(.textSecondary)
                .lineSpacing(3)
        }
        .multilineTextAlignment(alignment == .leading ? .leading : .center)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
    }

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

#if DEBUG
#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingPageView(page: OnboardingViewModel.allPages[2])
    }
}
#endif
