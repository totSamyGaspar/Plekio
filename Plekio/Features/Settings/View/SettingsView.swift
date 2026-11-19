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

    @State private var tipOptions: [TipOption] = []

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Custom title to match the other tabs; header trait kept for VoiceOver.
                Text("Settings")
                    .scaledFont(size: 30, relativeTo: .title, weight: .heavy, design: .serif)
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                List {
                    ProfileSection()

                    Section(header: Text("Appearance").foregroundStyle(Color.textSecondary)) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Theme", systemImage: theme.iconName)
                                    .foregroundStyle(Color.textPrimary)
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

                    AppLockSettingsSection()

                    Section(header: Text("Reminders").foregroundStyle(Color.textSecondary)) {

                        ForEach(DailyReminder.allCases) { reminder in
                            DailyReminderRows(reminder)
                        }
                        RefillReminderRows()
                    }
                    .listRowBackground(Color.appSurface)

                    Section(header: Text("Export").foregroundStyle(Color.textSecondary)) {
                        TipView(DoctorReportTip())
                        NavigationLink {
                            ReportExportView(viewModel: dependencies.makeReportExportViewModel())
                        } label: {
                            Label("Create document", systemImage: "doc.text")
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                    .listRowBackground(Color.appSurface)

                    StorageUsageSection()

                    Section(header: Text("About").foregroundStyle(Color.textSecondary)) {
                        HStack {
                            Text("Version")
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text(verbatim: AppBrand.version)
                                .foregroundStyle(Color.textSecondary)
                        }

                        HStack {
                            Text("Developer")
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text(verbatim: "Eduard Hasparian")
                                .foregroundStyle(Color.textSecondary)
                        }

                        FeedbackButton()

                        WebLinkRow(title: "Help & Support", systemImage: "questionmark.circle", url: AppBrand.supportURL)
                        WebLinkRow(title: "Privacy Policy", systemImage: "hand.raised", url: AppBrand.privacyPolicyURL)
                        WebLinkRow(title: "Terms of Use", systemImage: "doc.plaintext", url: AppBrand.termsURL)
                    }
                    .listRowBackground(Color.appSurface)

                    TipJarSection(options: tipOptions)
                }
                .scrollContentBackground(.hidden)
                .tint(.accentPrimary)
                .task { tipOptions = (try? await dependencies.tipJar.options()) ?? [] }
            }
        }
        .navigationTitle("Settings")
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        SettingsView()
            .appTheme()
    }
    .environment(AppDependencies.preview)
}
#endif
