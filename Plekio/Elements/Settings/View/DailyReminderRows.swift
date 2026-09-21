//
//  DailyReminderRows.swift
//  Plekio
//
//  One reminder's rows in Settings: the switch, and a time picker per time it
//  fires at. Written once for both reminders — they differ only in wording and
//  in how many times they allow, and a second copy would have been the place
//  the permission check or the re-arming quietly went missing.
//

import SwiftUI

struct DailyReminderRows: View {
    
    private let reminder: DailyReminder
    
    // The component reads and writes the reminder's own keys rather than being
    // handed bindings: the keys belong to the reminder, and threading them
    // through the Settings screen would only be a second place to get them wrong.
    @AppStorage private var isEnabled: Bool
    @AppStorage private var minutesRaw: String
    
    init(_ reminder: DailyReminder) {
        self.reminder = reminder
        self._isEnabled = AppStorage(wrappedValue: false, reminder.enabledKey)
        self._minutesRaw = AppStorage(wrappedValue: "", reminder.timesKey)
    }
    
    /// Falls back to the reminder's own defaults while nothing has been written,
    /// so the picker never opens on midnight.
    private var minutes: [Int] {
        let parsed = DailyReminder.minutes(fromRaw: minutesRaw, limit: reminder.maxTimes)
        return parsed.isEmpty ? reminder.defaultMinutesOfDay : parsed
    }
    
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
        // Attached to the switch because a multi-row body has no single view to
        // hang them on, and the switch is the one row that is always present.
        .onChange(of: isEnabled) { _, _ in apply() }
        .onChange(of: minutesRaw) { _, _ in apply() }
        
        // Only once the reminder is on: a time picker for something switched off
        // is a control with nothing to control.
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
                // A reminder with no times is a reminder that is on and never
                // fires — switching it off is what the user means by that.
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
        let service = DIContainer.shared.resolve(NotificationServiceProtocol.self)
        
        guard isEnabled else {
            service.cancelDailyReminder(reminder)
            return
        }
        
        let times = minutes
        Task {
            // Asked here rather than at launch: switching a reminder on is the
            // moment the permission is actually for something, and there is no
            // point arming a reminder that cannot fire.
            guard await service.requestPermission() else { return }
            await service.scheduleDailyReminder(reminder, minutesOfDay: times)
        }
    }
    
    // MARK: - Editing
    
    /// The picker speaks Date; the setting stores minutes since midnight, since a
    /// date would drag a day along with it for a time that repeats every day.
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
    
    /// Four hours after the last one, the same step the medication form offers —
    /// close enough to be a sensible next measurement, far enough not to collide
    /// with the time above it.
    private func addTime() {
        let last = minutes.last ?? reminder.defaultMinutesOfDay.first ?? 0
        write(minutes + [(last + 4 * 60) % (24 * 60)])
    }
    
    private func write(_ updated: [Int]) {
        minutesRaw = DailyReminder.raw(from: updated)
    }
}
