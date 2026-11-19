//
//  SplashView.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct SplashView: View {

    // MARK: - Properties

    private static let displayDuration: TimeInterval = 1.2

    /// UI tests skip the splash. Its 1.2 s only slows them, and a tap on the first
    /// screen while it is still fading in can be lost: SwiftUI drops a sheet
    /// requested mid-transition, which failed a test that tapped "Create a course".
    private static var startsActive: Bool {
        #if DEBUG
        UITestingLaunch.current != nil
        #else
        false
        #endif
    }

    @State private var isActive = Self.startsActive
    @State private var logoOpacity = 0.0

    @State private var isPulsing = false

    // MARK: - Body

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
                            .foregroundStyle(Color.textPrimary)
                            .italic()

                        Text("Your minimalist tracker")
                            .scaledFont(size: 11, relativeTo: .caption2, weight: .bold)
                            .foregroundStyle(Color.accentPrimary)
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

                withMotion(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
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

// MARK: - Preview

#if DEBUG
#Preview {
    SplashView()
        .environment(AppRouter())
        .environment(AppDependencies.preview)
}
#endif
