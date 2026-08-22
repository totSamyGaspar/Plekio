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
                .listRowBackground(Color.cardDark) // Dark background for settings rows

                Section {
                    Button(action: {
                        // No action yet
                    }) {
                        Label("Поддержать проект", systemImage: "cup.and.saucer.fill")
                            .foregroundColor(.neonMint)
                    }
                }
                .listRowBackground(Color.cardDark)
            }
            .scrollContentBackground(.hidden) // Remove the list's default gray background
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
