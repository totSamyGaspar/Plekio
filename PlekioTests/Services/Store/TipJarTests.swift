//
//  TipJarTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 30.09.2026.
//

import Testing
import StoreKitTest
@testable import Plekio

/// Against Plekio.storekit through StoreKitTest: no App Store, no account.
/// Serialized: the test session is shared by the whole process.
@MainActor
@Suite("Tip jar", .serialized)
struct TipJarTests {

    /// A clean store with purchase sheets confirmed automatically. Each test resets it
    /// in a defer: the session changes the simulator's StoreKit state, not just the
    /// test's, so a leftover Ask to Buy would also apply to the app run from Xcode.
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Plekio")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    @Test("Tips load cheapest first, each with its store price")
    func optionsLoadInPriceOrder() async throws {
        let session = try makeSession()
        defer { session.resetToDefaultState() }

        let options = try await StoreKitTipJar().options()

        #expect(options.map(\.tip) == [.small, .medium, .large])
        #expect(options.allSatisfy { !$0.displayPrice.isEmpty })
    }

    @Test("A tip goes through and is thanked")
    func tipIsThanked() async throws {
        let session = try makeSession()
        defer { session.resetToDefaultState() }
        let jar = StoreKitTipJar()
        _ = try await jar.options()

        #expect(try await jar.give(.small) == .thanked)
    }

    @Test("Ask to Buy leaves the tip pending")
    func askToBuyIsPending() async throws {
        let session = try makeSession()
        session.askToBuyEnabled = true
        defer { session.resetToDefaultState() }
        let jar = StoreKitTipJar()
        _ = try await jar.options()

        #expect(try await jar.give(.medium) == .pending)
    }

    @Test("Giving before the tips have loaded fails instead of guessing a product")
    func givingWithoutOptionsFails() async {
        await #expect(throws: TipFailed.self) {
            try await StoreKitTipJar().give(.small)
        }
    }
}
