//
//  OnboardingPageView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    @State private var isFloating = false
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // MARK: - Magic Icon Container
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [page.imageColor.opacity(0.4), Color.clear]),
                            center: .center,
                            startRadius: 10,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(isPulsing ? 1.2 : 0.8)
                    .opacity(isPulsing ? 0.8 : 0.3)
                
                Circle()
                    .fill(Color.cardDark)
                    .frame(width: 200, height: 200)
                    .overlay(
                        Circle().stroke(page.imageColor.opacity(0.4), lineWidth: 2)
                    )
                    .shadow(color: page.imageColor.opacity(isPulsing ? 0.4 : 0.1), radius: isPulsing ? 30 : 10, x: 0, y: isPulsing ? 15 : 5)
                
                Image(systemName: page.imageSystemName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.imageColor, page.imageColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: page.imageColor.opacity(0.8), radius: isFloating ? 20 : 5, x: 0, y: isFloating ? 10 : 0)
                    .offset(y: isFloating ? -12 : 8)
            }
            .padding(.vertical, 20)
            
            // MARK: - Text
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(.title2, design: .serif).weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
            }
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color.bgDark.ignoresSafeArea()
        OnboardingPageView(page: OnboardingPage(
            imageSystemName: "bell.badge.fill",
            imageColor: .orange,
            title: "Smart reminders",
            description: "Get timely notifications and log your medication right from the lock screen."
        ))
    }
}
