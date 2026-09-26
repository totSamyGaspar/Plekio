//
//  ReminderRowSupport.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

// MARK: - Binding+TimeOfDay

extension Binding where Value == Int {

    /// Minutes past midnight as today's date, for an hour-and-minute DatePicker.
    var timeOfDay: Binding<Date> {
        Binding<Date>(
            get: {
                let (hour, minute) = DailyReminder.hourAndMinute(from: wrappedValue)
                return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

// MARK: - View+NotificationsOffAlert

extension View {

    /// Shown when a reminder was switched on without notification permission.
    func notificationsOffAlert(isPresented: Binding<Bool>) -> some View {
        modifier(NotificationsOffAlert(isPresented: isPresented))
    }
}

private struct NotificationsOffAlert: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.alert("Notifications are off", isPresented: $isPresented) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To get this reminder, allow notifications for Plekio in the Settings app.")
        }
    }
}
