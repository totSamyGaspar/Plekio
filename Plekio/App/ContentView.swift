//
//  ContentView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

// MARK: - RootTransition

enum RootTransition {
    static let duration: TimeInterval = 0.5

    /// Delay before presenting a modal over a freshly shown root screen; longer
    /// than the animation because a request on its boundary can be swallowed.
    static let presentationDelay: TimeInterval = duration + 0.15
}

// MARK: - ContentView

struct ContentView: View {

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies
    @AppStorage(SettingsKey.hasSeenOnboarding) var hasSeenOnboarding: Bool = false

    // MARK: - Body

    var body: some View {
        Group {
            if hasSeenOnboarding {
                MainTabView()
                    .transition(.opacity)
                    .onAppear {
                        let notifService = dependencies.notifications
                        Task { await notifService.requestPermission() }
                    }
            } else {
                OnboardingView(viewModel: dependencies.makeOnboardingViewModel())
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: RootTransition.duration), value: hasSeenOnboarding)
        .appTheme()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppRouter())
        .environment(AppDependencies.preview)
}
