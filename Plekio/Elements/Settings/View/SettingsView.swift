//
//  SettingsView.swift
//  Plekio
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
            
            VStack(alignment: .leading, spacing: 0) {
                // Drawn rather than left to the navigation bar: the other three
                // tabs draw their own titles, and a system large title here was
                // the one screen that behaved differently. The header trait is
                // added by hand because that is what the system title provided
                // and VoiceOver still needs.
                Text("Settings")
                    .scaledFont(size: 30, relativeTo: .title, weight: .heavy, design: .serif)
                    .foregroundColor(.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
                List {
                    ProfileSection()

                    Section(header: Text("Appearance").foregroundColor(.textSecondary)) {
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
                    
                    Section(header: Text("Reminders").foregroundColor(.textSecondary)) {

                        ForEach(DailyReminder.allCases) { reminder in
                            DailyReminderRows(reminder)
                        }
                    }
                    .listRowBackground(Color.appSurface)
                    
                    Section(header: Text("Export").foregroundColor(.textSecondary)) {
                        NavigationLink {
                            ReportExportView()
                        } label: {
                            Label("Create document", systemImage: "doc.text")
                                .foregroundColor(.textPrimary)
                        }
                    }
                    .listRowBackground(Color.appSurface)

                    StorageUsageSection()

                    Section(header: Text("About").foregroundColor(.textSecondary)) {
                        HStack {
                            Text("Version")
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.textSecondary)
                        }
                        
                        HStack {
                            Text("Developer")
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Text("Edward Gasparian")
                                .foregroundColor(.textSecondary)
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
        }
        .navigationTitle("Settings")
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .appTheme()
    }
}
