//
//  ContentView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

/// Transition between root screens: splash → ContentView → onboarding/tab bar.
///
/// Shared rather than inlined per view because more than the animation depends
/// on this duration: SwiftUI silently drops a `fullScreenCover` requested while
/// the presenting view is still appearing. That is why a notification tapped on
/// a cold launch used to open the dashboard with no modal — the push arrived
/// before MainTabView was in the hierarchy, so the modal was requested right in
/// the middle of the appear animation.
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
                        notifService.requestPermission()
                    }
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: RootTransition.duration), value: hasSeenOnboarding)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppRouter())
}
