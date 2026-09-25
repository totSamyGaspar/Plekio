//
//  SplashView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct SplashView: View {
    /// Nothing loads behind the splash — it is pure branding, so it stays up
    /// exactly as long as the logo fade-in takes and not a moment longer.
    private static let displayDuration: TimeInterval = 1.2

    @State private var isActive = false
    @State private var logoOpacity = 0.0
    
    @State private var isPulsing = false
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.splashTint,
                        Color.appBackground,
                        Color.appBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // MARK: - Animated logo
                    AppLogo(size: 116)
                        .shadow(
                            color: .accentPrimary.opacity(isPulsing ? 0.55 : 0.2),
                            radius: isPulsing ? 26 : 12
                        )
                        .scaleEffect(isPulsing ? 1.04 : 0.96)
                        .opacity(logoOpacity)
                    
                    VStack(spacing: 8) {
                        Text(AppBrand.name)
                            .scaledFont(size: 42, relativeTo: .largeTitle, weight: .heavy, design: .serif)
                            .foregroundColor(.textPrimary)
                            .italic()
                        
                        Text("Your minimalist tracker")
                            .scaledFont(size: 11, relativeTo: .caption2, weight: .bold)
                            .foregroundColor(.accentPrimary)
                            .tracking(1.5)
                    }
                    .opacity(logoOpacity)
                    
                    Spacer()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentPrimary))
                        .scaleEffect(1.2)
                        .padding(.bottom, 60)
                }
            }
            .appTheme()
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) {
                    self.logoOpacity = 1.0
                }

                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    self.isPulsing = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + Self.displayDuration) {
                    withAnimation(.easeInOut(duration: RootTransition.duration)) {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(AppRouter())
        .environment(AppDependencies.preview)
}
