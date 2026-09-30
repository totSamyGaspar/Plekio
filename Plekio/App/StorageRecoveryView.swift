//
//  StorageRecoveryView.swift
//  Plekio
//
//  Created by Edward Gasparian on 30.09.2026.
//

import SwiftUI

/// Shown instead of the app when the store can't be opened. Says the data is
/// still there, retries, and offers a fresh start only behind a confirmation.
struct StorageRecoveryView: View {

    let launcher: AppLauncher

    @State private var confirmsStartFresh = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundColor(.accentPrimary)
                .accessibilityHidden(true)

            Text("Couldn't load your data")
                .font(.title2.bold())
                .foregroundColor(.textPrimary)

            Text("Your entries are still on this device, but Plekio can't open them right now. Reminders that are already scheduled keep coming.")
                .foregroundColor(.textSecondary)

            Text("If your iPhone is almost out of storage, free up some space, then try again.")
                .font(.footnote)
                .foregroundColor(.textSecondary)

            Spacer()

            Button("Try Again", action: launcher.retry)
                .buttonStyle(OnboardingButtonStyle())

            FeedbackButton(details: launcher.failureDetails)

            Button("Start Fresh", role: .destructive) { confirmsStartFresh = true }
                .font(.subheadline)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
        .confirmationDialog("Start with empty data?", isPresented: $confirmsStartFresh, titleVisibility: .visible) {
            Button("Start Fresh", role: .destructive, action: launcher.startFresh)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current data is set aside, not deleted, so a later update can still recover it.")
        }
        .appTheme()
    }
}

// MARK: - Preview

#Preview {
    StorageRecoveryView(launcher: AppLauncher(
        location: StorageLocation(root: FileManager.default.temporaryDirectory.appending(path: "PlekioPreviewRecovery"))
    ) { _ in throw CocoaError(.fileReadCorruptFile) })
}
