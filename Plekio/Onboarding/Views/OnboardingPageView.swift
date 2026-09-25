//
//  OnboardingPageView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

/// A slide: a piece of the real interface over a glow, and the two lines that
/// explain it.
///
/// The miniature replaced an icon in a circle on purpose. An icon describes
/// the product; a fragment of the product shows it, and someone deciding
/// whether to keep the app has seen it before the first tap.
struct OnboardingPageView: View {

    let page: OnboardingPage

    @State private var isGlowing = false

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
        // The miniature carries no information the two lines below it do not,
        // so VoiceOver reads the slide as one thing and skips the decoration.
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch page.preview {
        case .course: CoursePreview()
        case .day: DayPreview()
        case .reminder: ReminderPreview()
        case .diary: DiaryPreview()
        case .report: ReportPreview()
        }
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        OnboardingPageView(page: OnboardingViewModel().pages[2])
    }
}
