import Foundation
import LocalAuthentication

@MainActor
protocol DeviceAuthenticating: AnyObject {
    func authenticate() async throws -> Bool
    func cancel()
}

@MainActor
final class DeviceAuthenticator: DeviceAuthenticating {
    private var context: LAContext?

    func authenticate() async throws -> Bool {
        let context = LAContext()
        self.context = context
        defer { self.context = nil }
        return try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: String(localized: "Unlock Plekio to access your health data.")
        )
    }

    func cancel() { context?.invalidate() }
}
