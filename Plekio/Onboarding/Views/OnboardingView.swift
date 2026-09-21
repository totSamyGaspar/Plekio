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
        VStack {
            TabView(selection: $viewModel.currentPage) {
                ForEach(0..<viewModel.pages.count, id: \.self) { index in
                    OnboardingPageView(page: viewModel.pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Spacer()

            bottomButton
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private var bottomButton: some View {
        if viewModel.isLastPage {
            Button(action: { isCollectingProfile = true }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentPrimary)
                    .cornerRadius(16)
                    .shadow(color: Color.accentPrimary.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            Color.clear
                .frame(height: 50)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
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
