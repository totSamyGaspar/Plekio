import Foundation
import Observation
import LocalAuthentication

@Observable
@MainActor
final class AppLock {
    private(set) var isEnabled: Bool
    private(set) var isLocked: Bool
    private(set) var isAuthenticating = false
    var showsError = false
    private let settings: SettingsStore
    private let authenticator: any DeviceAuthenticating
    private var generation = 0

    init(settings: SettingsStore, authenticator: any DeviceAuthenticating) {
        self.settings = settings
        self.authenticator = authenticator
        isEnabled = settings.isAppLockEnabled
        isLocked = settings.isAppLockEnabled
    }

    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled, !isAuthenticating else { return }
        guard await authenticate() else { return }
        settings.isAppLockEnabled = enabled
        isEnabled = enabled
        isLocked = false
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        if await authenticate() { isLocked = false }
    }

    func enteredBackground() {
        generation += 1
        authenticator.cancel()
        // Keep the in-flight attempt busy until it unwinds, so contexts cannot overlap.
        isLocked = isEnabled
        showsError = false
    }

    private func authenticate() async -> Bool {
        isAuthenticating = true
        showsError = false
        let attempt = generation
        defer { isAuthenticating = false }
        do {
            let success = try await authenticator.authenticate()
            guard attempt == generation else { return false }
            showsError = !success
            return success
        } catch {
            guard attempt == generation else { return false }
            let code = (error as? LAError)?.code
            showsError = code != .userCancel && code != .systemCancel && code != .appCancel
            return false
        }
    }
}
