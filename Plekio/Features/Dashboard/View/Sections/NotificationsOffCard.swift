//
//  NotificationsOffCard.swift
//  Plekio
//
//  Created by Edward Gasparian on 11.11.2026.
//

import SwiftUI

/// Above everything else on Today: without notifications not one dose is reminded.
struct NotificationsOffCard: View {

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "bell.slash.fill")
                Text("Notifications are off")
            }
            .font(.headline.weight(.bold))
            .foregroundColor(.warningAccent)

            Text("Plekio can't remind you about your doses. Allow notifications for Plekio in the Settings app.")
                .font(.subheadline)
                .foregroundColor(.textPrimary.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentPrimary)
                    .cornerRadius(12)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .cornerRadius(24)
        .padding(.horizontal)
    }
}
