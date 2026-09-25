//
//  DailyReminderRows.swift
//  Plekio
//
//  Created by Edward Gasparian on 04.09.2026.
//

import SwiftUI

struct DailyReminderRows: View {

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.openURL) private var openURL

    /// Shown when the reminder was switched on without notification permission; the switch is already back off.
    @State private var showingPermissionAlert = false

    private let reminder: DailyReminder

    // Bound to the reminder's own storage keys rather than passed-in bindings.
    @AppStorage private var isEnabled: Bool
    @AppStorage private var minutesRaw: String

    // MARK: - Init

    init(_ reminder: DailyReminder) {
        self.reminder = reminder
        self._isEnabled = AppStorage(wrappedValue: false, reminder.enabledKey)
        self._minutesRaw = AppStorage(wrappedValue: "", reminder.timesKey)
    }

    /// Falls back to the reminder's defaults while nothing is stored, so the picker never opens on midnight.
    private var minutes: [Int] {
        let parsed = DailyReminder.minutes(fromRaw: minutesRaw, limit: reminder.maxTimes)
        return parsed.isEmpty ? reminder.defaultMinutesOfDay : parsed
    }

    // MARK: - Body

    var body: some View {
        Toggle(isOn: $isEnabled) {
            Label {
                Text(reminder.settingsTitle)
            } icon: {
                Image(systemName: reminder.settingsIcon)
            }
            .foregroundColor(.textPrimary)
        }
        .tint(.accentPrimary)
        // On the switch: it is the only row that is always present.
        .onChange(of: isEnabled) { _, _ in apply() }
        .onChange(of: minutesRaw) { _, _ in apply() }
        .alert("Notifications are off", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To get this reminder, allow notifications for Plekio in the Settings app.")
        }

        if isEnabled {
            ForEach(Array(minutes.enumerated()), id: \.offset) { index, _ in
                DatePicker(
                    "Reminder time",
                    selection: time(at: index),
                    displayedComponents: .hourAndMinute
                )
                .foregroundColor(.textPrimary)
            }
            .onDelete { offsets in
                // Never delete the last time; switching off is how a reminder goes away.
                guard minutes.count > offsets.count else { return }
                var updated = minutes
                updated.remove(atOffsets: offsets)
                write(updated)
            }

            if minutes.count < reminder.maxTimes {
                Button(action: addTime) {
                    Label("Add time", systemImage: "plus.circle.fill")
                        .foregroundColor(.accentPrimary)
                }
            }
        }
    }

    // MARK: - Arming

    private func apply() {
        let arming = dependencies.dailyReminderArming
        let enabled = isEnabled
        let times = minutes

        Task {
            let result = await arming.apply(reminder, enabled: enabled, minutesOfDay: times)
            guard result == .permissionDenied else { return }

            // Never show "on" for a reminder that cannot fire.
            isEnabled = false
            showingPermissionAlert = true
        }
    }

    // MARK: - Editing

    /// Bridges the Date picker to the stored minutes since midnight.
    private func time(at index: Int) -> Binding<Date> {
        Binding(
            get: {
                let minute = minutes.indices.contains(index) ? minutes[index] : 0
                let (hour, minuteOfHour) = DailyReminder.hourAndMinute(from: minute)
                return Calendar.current.date(
                    bySettingHour: hour, minute: minuteOfHour, second: 0, of: Date()
                ) ?? Date()
            },
            set: { newValue in
                var updated = minutes
                guard updated.indices.contains(index) else { return }
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                updated[index] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                write(updated)
            }
        )
    }

    /// Adds a time four hours after the last one, wrapping past midnight.
    private func addTime() {
        let last = minutes.last ?? reminder.defaultMinutesOfDay.first ?? 0
        write(minutes + [(last + 4 * 60) % (24 * 60)])
    }

    private func write(_ updated: [Int]) {
        minutesRaw = DailyReminder.raw(from: updated)
    }
}
