import SwiftUI

struct AppLockSettingsSection: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        @Bindable var lock = dependencies.appLock
        Section {
            Toggle(isOn: Binding(get: { lock.isEnabled }, set: { enabled in
                Task { await lock.setEnabled(enabled) }
            })) {
                Label("Face ID / Device passcode", systemImage: "faceid")
                    .foregroundStyle(Color.textPrimary)
            }
            .disabled(lock.isAuthenticating)
        } header: {
            Text("Security").foregroundStyle(Color.textSecondary)
        } footer: {
            Text("Require authentication when opening Plekio. Uses Face ID, Touch ID, or your device passcode.")
        }
        .listRowBackground(Color.appSurface)
        .alert("Could not verify your identity", isPresented: $lock.showsError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Authentication failed. Try again or use your device passcode.")
        }
    }
}
