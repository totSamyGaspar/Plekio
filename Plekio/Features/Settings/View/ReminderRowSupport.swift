//
//  ReminderRowSupport.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

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
