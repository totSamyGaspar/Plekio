//
//  RefillReminderRows.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

/// On/off and time for the daily "running low" reminder.
struct RefillReminderRows: View {

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies

    @State private var showingPermissionAlert = false

    // Same keys and defaults as SettingsStore, which the reminder rebuild reads.
    @AppStorage(SettingsKey.refillReminderEnabled) private var isEnabled = true
    @AppStorage(SettingsKey.refillReminderMinuteOfDay) private var minuteOfDay = RefillReminder.defaultMinuteOfDay

    // MARK: - Body

    var body: some View {
        Toggle(isOn: $isEnabled) {
            Label("Low stock", systemImage: "pills")
                .foregroundColor(.textPrimary)
        }
        .tint(.accentPrimary)
        .onChange(of: isEnabled) { _, isOn in isOn ? enable() : rebuild() }
        .onChange(of: minuteOfDay) { _, _ in rebuild() }
        .notificationsOffAlert(isPresented: $showingPermissionAlert)

        if isEnabled {
            DatePicker("Reminder time", selection: $minuteOfDay.timeOfDay, displayedComponents: .hourAndMinute)
                .foregroundColor(.textPrimary)
        }
    }

    // MARK: - Actions

    private func enable() {
        let notifications = dependencies.notifications
        Task {
            guard await notifications.requestPermission() else {
                // Never show "on" for a reminder that cannot fire.
                isEnabled = false
                showingPermissionAlert = true
                return
            }
            rebuild()
        }
    }

    /// The refill reminder is planned with the rest of the queue.
    private func rebuild() {
        dependencies.reminderSync.sync()
    }
}
