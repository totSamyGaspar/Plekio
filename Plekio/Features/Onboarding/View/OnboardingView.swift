//
//  OnboardingView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct OnboardingView<VM: OnboardingViewModelProtocol>: View {

    // MARK: - Properties

    @StateObject private var viewModel: VM

    /// Shown after the carousel; view state, since the view model knows only the pages.
    @State private var isCollectingProfile = false

    // MARK: - Init

    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if isCollectingProfile {
                OnboardingProfileStep(onFinish: viewModel.completeOnboarding)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                carousel
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isCollectingProfile)
    }

    // MARK: - Subviews

    private var carousel: some View {
        VStack(spacing: 0) {
            TabView(selection: $viewModel.currentPage) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page, isActive: index == viewModel.currentPage)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots.padding(.vertical, 26)

            actions
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
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
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.currentPage)
        .accessibilityHidden(true)
    }

    /// Skip goes to the profile step, not out of onboarding.
    private var actions: some View {
        VStack(spacing: 14) {
            Button {
                if viewModel.isLastPage {
                    isCollectingProfile = true
                } else {
                    withAnimation { viewModel.currentPage += 1 }
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

#Preview {
    OnboardingView(viewModel: MockOnboardingViewModel())
}
