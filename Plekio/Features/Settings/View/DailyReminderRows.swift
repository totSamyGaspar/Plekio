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
        .notificationsOffAlert(isPresented: $showingPermissionAlert)

        if isEnabled {
            // Switching off, not deleting the last time, is how a reminder goes away.
            TimeOfDayRows(
                minutes: Binding(get: { minutes }, set: { minutesRaw = DailyReminder.raw(from: $0) }),
                maxCount: reminder.maxTimes
            ) { _ in Text("Reminder time") }
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
}
