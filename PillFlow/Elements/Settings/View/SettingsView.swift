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

    @AppStorage(DiaryReminderSettings.enabledKey) private var diaryReminderEnabled = false
    @AppStorage(DiaryReminderSettings.minuteOfDayKey)
    private var reminderMinuteOfDay = DiaryReminderSettings.defaultMinuteOfDay

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
                        Toggle(isOn: $diaryReminderEnabled) {
                            Label("Diary reminder", systemImage: "text.book.closed.fill")
                                .foregroundColor(.textPrimary)
                        }
                        .tint(.accentPrimary)

                        // Only once the reminder is on: a time picker for something
                        // switched off is a control with nothing to control.
                        if diaryReminderEnabled {
                            DatePicker(
                                "Reminder time",
                                selection: reminderTime,
                                displayedComponents: .hourAndMinute
                            )
                            .foregroundColor(.textPrimary)
                        }
                    }
                    .listRowBackground(Color.appSurface)
                    .onChange(of: diaryReminderEnabled) { _, _ in applyDiaryReminder() }
                    .onChange(of: reminderMinuteOfDay) { _, _ in applyDiaryReminder() }

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

    /// The picker speaks Date; the setting stores minutes since midnight, since a
    /// date would drag a day along with it for a time that repeats every day.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                let (hour, minute) = DiaryReminderSettings.hourAndMinute(from: reminderMinuteOfDay)
                return Calendar.current.date(
                    bySettingHour: hour, minute: minute, second: 0, of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderMinuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private func applyDiaryReminder() {
        let service = DIContainer.shared.resolve(NotificationServiceProtocol.self)
        guard diaryReminderEnabled else {
            service.cancelDiaryReminder()
            return
        }
        Task {
            // Asked here rather than at launch: switching the reminder on is the
            // moment the permission is actually for something. Now that the answer
            // comes back, there is no point arming a reminder that cannot fire.
            guard await service.requestPermission() else { return }
            await service.scheduleDiaryReminder(minuteOfDay: reminderMinuteOfDay)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .appTheme()
    }
}
