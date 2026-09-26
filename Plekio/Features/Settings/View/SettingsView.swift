//
//  SettingsView.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI
import TipKit

struct SettingsView: View {

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies
    // Read straight from defaults: every theme-aware screen reads this same key.
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Custom title to match the other tabs; header trait kept for VoiceOver.
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
                        TipView(DoctorReportTip())
                        NavigationLink {
                            ReportExportView(viewModel: dependencies.makeReportExportViewModel())
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
                    .listRowBackground(Color.appSurface)

                    Section {
                        Button(action: {
                        }) {
                            Label("Support the project", systemImage: "cup.and.saucer.fill")
                                .foregroundColor(.accentPrimary)
                        }
                    }
                    .listRowBackground(Color.appSurface)
                }
                .scrollContentBackground(.hidden)
                .tint(.accentPrimary)
            }
        }
        .navigationTitle("Settings")
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
            .appTheme()
    }
    .environment(AppDependencies.preview)
}
