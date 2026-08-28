//
//  SettingsView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI

struct SettingsView: View {
    /// Read straight from defaults rather than through a view model: every
    /// screen that reacts to the theme reads the same key, so a store in
    /// between would only add a second place for it to go stale.
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .dark

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            List {
                Section(header: Text("Appearance").foregroundColor(.textPrimary.opacity(0.6))) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Theme", systemImage: theme.iconName)
                                .foregroundColor(.textPrimary)
                            Spacer()
                        }

                        Picker("Theme", selection: $theme) {
                            ForEach(AppTheme.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.appSurface)

                Section(header: Text("About").foregroundColor(.textPrimary.opacity(0.6))) {
                    HStack {
                        Text("Version")
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.textPrimary.opacity(0.5))
                    }
                    
                    HStack {
                        Text("Developer")
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Text("Edward Gasparian")
                            .foregroundColor(.textPrimary.opacity(0.5))
                    }
                }
                .listRowBackground(Color.appSurface) // Card background for settings rows

                Section {
                    Button(action: {
                        // No action yet
                    }) {
                        Label("Support the project", systemImage: "cup.and.saucer.fill")
                            .foregroundColor(.accentPrimary)
                    }
                }
                .listRowBackground(Color.appSurface)
            }
            .scrollContentBackground(.hidden) // Remove the list's default gray background
            .tint(.accentPrimary)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .appTheme()
    }
}
