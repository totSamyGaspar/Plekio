//
//  SplashView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var logoOpacity = 0.0
    
    // Новые стейты для магии анимаций
    @State private var isPulsing = false
    @State private var isFloating = false
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                // Стильный темный градиент для Splash-экрана
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.25, blue: 0.22),
                        Color.bgDark,
                        Color.bgDark
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // MARK: - Магический логотип
                    ZStack {
                        // Сердце (градиент + биение + динамическое свечение)
                        Image(systemName: "heart.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 110)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.4, blue: 0.5), Color(red: 0.7, green: 0.1, blue: 0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(red: 1.0, green: 0.3, blue: 0.4).opacity(isPulsing ? 0.6 : 0.2),
                                    radius: isPulsing ? 20 : 10,
                                    x: 0,
                                    y: isPulsing ? 10 : 5)
                            .scaleEffect(isPulsing ? 1.05 : 0.95)
                        
                        // Часы (вырез с легким внутренним бликом)
                        Image(systemName: "clock.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 38, height: 38)
                            .foregroundColor(Color.bgDark)
                            .background(Circle().fill(Color.white.opacity(0.1)).frame(width: 26, height: 26))
                            .offset(x: -20, y: -20)
                        
                        // Пилюли (неоновый градиент + левитация)
                        Image(systemName: "pills.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 45, height: 45)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.neonMint, .teal],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.neonMint.opacity(0.8), radius: isFloating ? 15 : 5, x: 0, y: 0)
                            .offset(x: 22, y: isFloating ? 10 : 20)
                            .rotationEffect(.degrees(isFloating ? -10 : -20))
                    }
                    .opacity(logoOpacity)
                    
                    VStack(spacing: 8) {
                        Text("PillFlow")
                            .font(.system(size: 42, weight: .heavy, design: .serif))
                            .foregroundColor(.white)
                            .italic()
                        
                        Text("Your minimalist tracker")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.neonMint)
                            .tracking(1.5)
                    }
                    .opacity(logoOpacity)
                    
                    Spacer()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .neonMint))
                        .scaleEffect(1.2)
                        .padding(.bottom, 60)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                // Плавное появление всего экрана
                withAnimation(.easeOut(duration: 1.2)) {
                    self.logoOpacity = 1.0
                }
                
                // Запуск биения сердца (быстрая пульсация)
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    self.isPulsing = true
                }
                
                // Запуск левитации пилюль (медленное покачивание)
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    self.isFloating = true
                }
                
                // Переход на главный экран
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
