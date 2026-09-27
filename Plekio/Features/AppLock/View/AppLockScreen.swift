import SwiftUI

struct AppLockScreen: View {
    let lock: AppLock

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentPrimary)
                Text("Plekio is locked").font(.title2.bold())
                Button("Unlock") { Task { await lock.unlock() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(lock.isAuthenticating)
                if lock.isAuthenticating { ProgressView() }
                if lock.showsError {
                    Text("Authentication failed. Try again or use your device passcode.")
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
        }
    }
}
