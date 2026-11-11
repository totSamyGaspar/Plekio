//
//  OnboardingView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct OnboardingView<VM: OnboardingViewModelProtocol>: View {

    // MARK: - Properties

    @StateModel private var viewModel: VM

    /// Shown after the carousel; view state, since the view model knows only the pages.
    @State private var isCollectingProfile = false

    @State private var isWide = false
    @State private var isLarge = false

    // MARK: - Init

    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateModel(wrappedValue: viewModel())
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            // The space given, not the content: the content's size changes with the layout.
            Color.clear
                .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { isWide = $0 }
                // An iPad, in either orientation; not a phone on its side.
                .onGeometryChange(for: Bool.self) { min($0.size.width, $0.size.height) >= 700 } action: { isLarge = $0 }
                .accessibilityHidden(true)

            if isCollectingProfile {
                OnboardingProfileStep(isWide: isWide, onFinish: viewModel.completeOnboarding)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                carousel
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .motion(.easeInOut(duration: 0.35), value: isCollectingProfile)
    }

    // MARK: - Subviews

    private var carousel: some View {
        VStack(spacing: 0) {
            TabView(selection: $viewModel.currentPage) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page, isActive: index == viewModel.currentPage, isWide: isWide, isLarge: isLarge)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots.padding(.vertical, isWide ? 16 : 26)

            actions
                .frame(maxWidth: OnboardingLayout.actionsMaxWidth)
                .padding(.horizontal, 24)
                .padding(.bottom, isWide ? 20 : 40)
        }
    }

    /// Custom dots: TabView's can't show a longer current capsule and sit inside the pages.
    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == viewModel.currentPage ? Color.accentPrimary : Color.textPrimary.opacity(0.15))
                    .frame(width: index == viewModel.currentPage ? 22 : 7, height: 7)
            }
        }
        .motion(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.currentPage)
        .accessibilityHidden(true)
    }

    /// Skip goes to the profile step, not out of onboarding.
    private var actions: some View {
        VStack(spacing: 14) {
            Button {
                if viewModel.isLastPage {
                    isCollectingProfile = true
                } else {
                    withMotion { viewModel.currentPage += 1 }
                }
            } label: {
                Text("Continue")
            }
            .buttonStyle(OnboardingButtonStyle())

            Button("Skip") { isCollectingProfile = true }
                .font(.subheadline)
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    OnboardingView(viewModel: MockOnboardingViewModel())
}
#endif
