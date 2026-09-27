import Foundation
import LocalAuthentication
import Testing
@testable import Plekio

@MainActor
struct AppLockTests {
    @MainActor
    private final class Authenticator: DeviceAuthenticating {
        var result = true
        var error: Error?
        var onAuthenticate: (() -> Void)?
        var cancellations = 0
        func authenticate() async throws -> Bool {
            onAuthenticate?()
            if let error { throw error }
            return result
        }
        func cancel() { cancellations += 1 }
    }

    @MainActor
    private final class Harness {
        let suite = "PlekioTests.AppLock.\(UUID().uuidString)"
        let settings: SettingsStore
        let auth = Authenticator()
        let lock: AppLock
        init(enabled: Bool = false) {
            settings = SettingsStore(defaults: UserDefaults(suiteName: suite)!)
            settings.isAppLockEnabled = enabled
            lock = AppLock(settings: settings, authenticator: auth)
        }
        deinit { UserDefaults().removePersistentDomain(forName: suite) }
    }

    @Test
    func defaultsToDisabled() {
        let h = Harness()
        #expect(!h.lock.isEnabled && !h.lock.isLocked)
    }

    @Test
    func enablingPersistsOnlyAfterSuccessfulAuthentication() async {
        let h = Harness()
        h.auth.result = false
        await h.lock.setEnabled(true)
        #expect(!h.settings.isAppLockEnabled && !h.lock.isEnabled)
        h.auth.result = true
        await h.lock.setEnabled(true)
        #expect(h.settings.isAppLockEnabled && h.lock.isEnabled && !h.lock.isLocked)
    }

    @Test
    func enabledLockStartsLockedAndRelocksInBackground() async {
        let h = Harness(enabled: true)
        #expect(h.lock.isLocked)
        await h.lock.unlock()
        #expect(!h.lock.isLocked)
        h.lock.enteredBackground()
        #expect(h.lock.isLocked)
    }

    @Test
    func cancellationKeepsLockedAndAllowsRetry() async {
        let h = Harness(enabled: true)
        h.auth.error = LAError(.userCancel)
        await h.lock.unlock()
        #expect(h.lock.isLocked && !h.lock.isAuthenticating && !h.lock.showsError)
        h.auth.error = nil
        await h.lock.unlock()
        #expect(!h.lock.isLocked)
    }

    @Test
    func disablingRequiresAuthentication() async {
        let h = Harness(enabled: true)
        h.auth.result = false
        await h.lock.setEnabled(false)
        #expect(h.lock.isEnabled && h.settings.isAppLockEnabled)
        h.auth.result = true
        await h.lock.setEnabled(false)
        #expect(!h.lock.isEnabled && !h.lock.isLocked && !h.settings.isAppLockEnabled)
    }

    @Test
    func backgroundInvalidatesSuccessfulAuthentication() async {
        let h = Harness(enabled: true)
        h.auth.onAuthenticate = { h.lock.enteredBackground() }
        await h.lock.unlock()
        #expect(h.lock.isLocked && h.auth.cancellations == 1)
        #expect(!h.lock.isAuthenticating)
    }

    @Test
    func backgroundPreventsSettingsChange() async {
        let h = Harness()
        h.auth.onAuthenticate = { h.lock.enteredBackground() }
        await h.lock.setEnabled(true)
        #expect(!h.lock.isEnabled && !h.settings.isAppLockEnabled)
    }

    @Test
    func unavailableAuthenticationDoesNotDisableProtection() async {
        let h = Harness(enabled: true)
        h.auth.error = LAError(.passcodeNotSet)
        await h.lock.unlock()
        #expect(h.lock.isLocked && h.lock.isEnabled && h.lock.showsError)
    }
}
