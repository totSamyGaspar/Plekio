//
//  ReminderPreview.swift
//  Plekio
//

import SwiftUI

/// Slide 3: the notification, with its two actions, on a lock screen.
///
/// Drawn as the system draws it — translucent, its own corner radius, the app
/// name in caps — because the claim of the slide is that this is where the
/// work happens. A card in the app's own style would undercut it.
struct ReminderPreview: View {

    var body: some View {
        VStack(spacing: 18) {
            Text(verbatim: "14:00")
                .font(.system(size: 52, weight: .bold, design: .serif))
                .foregroundColor(.textPrimary.opacity(0.55))

            notification

            HStack(spacing: 7) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                Text("Lock screen")
                    .font(.system(size: 13))
            }
            .foregroundColor(.textSecondary)
        }
    }

    private var notification: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    AppLogo(size: 16)
                    Text(AppBrand.name)
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                    Spacer(minLength: 0)
                    Text("now")
                        .font(.system(size: 11))
                }
                .foregroundColor(.textSecondary)

                Text(verbatim: "Ibuprofen")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text(verbatim: "2 · 14:00")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Rectangle()
                .fill(Color.textPrimary.opacity(0.12))
                .frame(height: 1)

            HStack(spacing: 0) {
                action("Taken", color: .accentPrimary, weight: .semibold)
                Rectangle()
                    .fill(Color.textPrimary.opacity(0.12))
                    .frame(width: 1, height: 44)
                action("Skip", color: .textSecondary, weight: .regular)
            }
        }
        .frame(width: 306)
        .background(Color.appSurface)
        .clipShape(.rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.textPrimary.opacity(0.1), lineWidth: 1)
        )
    }

    private func action(_ title: LocalizedStringResource, color: Color, weight: Font.Weight) -> some View {
        Text(title)
            .font(.system(size: 15, weight: weight))
            .foregroundColor(color)
            .frame(maxWidth: .infinity, minHeight: 44)
    }
}

#Preview {
    ReminderPreview()
        .padding(40)
        .background(Color.appBackground)
}
