//
//  OnboardingView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct OnboardingView<VM: OnboardingViewModelProtocol>: View {

    @StateObject private var viewModel: VM

    /// The profile step is view state, not view-model state: it is one step
    /// added after the pages, and the carousel knows nothing about it.
    @State private var isCollectingProfile = false

    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

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

    private var carousel: some View {
        VStack(spacing: 0) {
            TabView(selection: $viewModel.currentPage) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots.padding(.vertical, 26)

            actions
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
    }

    // MARK: - UI Components

    /// Drawn rather than taken from `TabView`. Its own dots cannot show the
    /// current page as a longer capsule, and they sit inside the paging area,
    /// where the slide's text needs the room.
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

    /// Both actions are on every slide. An onboarding you cannot leave annoys
    /// more than it helps, and Skip lands on the profile step rather than
    /// outside: the two fields there are the only thing the app actually needs.
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

extension OnboardingView where VM == OnboardingViewModel {
    init() {
        let resolvedViewModel = DIContainer.shared.resolve(OnboardingViewModel.self)
        self.init(viewModel: resolvedViewModel)
    }
}

#Preview {
    OnboardingView(viewModel: MockOnboardingViewModel())
}
