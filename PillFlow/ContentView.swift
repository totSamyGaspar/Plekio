//
//  ContentView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

// ContentView.swift
import SwiftUI

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
        .animation(.easeInOut(duration: 0.5), value: hasSeenOnboarding)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppRouter())
}
