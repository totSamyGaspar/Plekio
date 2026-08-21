//
//  SettingsView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()
            
            List {
                Section(header: Text("О приложении").foregroundColor(.white.opacity(0.6))) {
                    HStack {
                        Text("Версия")
                            .foregroundColor(.white)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    HStack {
                        Text("Разработчик")
                            .foregroundColor(.white)
                        Spacer()
                        Text("Edward Gasparian")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .listRowBackground(Color.cardDark) // Темные плашки настроек
                
                Section {
                    Button(action: {
                        // Пока ничего не делает
                    }) {
                        Label("Поддержать проект", systemImage: "cup.and.saucer.fill")
                            .foregroundColor(.neonMint)
                    }
                }
                .listRowBackground(Color.cardDark)
            }
            .scrollContentBackground(.hidden) // Убираем серый фон списка
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .preferredColorScheme(.dark)
    }
}
