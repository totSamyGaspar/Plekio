//
//  ContentView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

enum RootTransition {
    static let duration: TimeInterval = 0.5

    /// How long to wait before presenting a modal over a root screen that has
    /// just appeared. Deliberately a little longer than the animation: a request
    /// landing exactly on its boundary can still be swallowed.
    static let presentationDelay: TimeInterval = duration + 0.15
}

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    
    var body: some View {
        Group {
            if hasSeenOnboarding {
                MainTabView()
                    .transition(.opacity)
                    .onAppear {
                        let notifService = DIContainer.shared.resolve(NotificationServiceProtocol.self)
                        Task { await notifService.requestPermission() }
                    }
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: RootTransition.duration), value: hasSeenOnboarding)
        .appTheme()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppRouter())
}
