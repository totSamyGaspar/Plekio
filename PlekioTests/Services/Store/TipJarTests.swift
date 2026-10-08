//
//  TipJarTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 30.09.2026.
//

import Testing
import Foundation
import StoreKit
import StoreKitTest
@testable import Plekio

@MainActor
@Suite("Tip jar", .serialized, .timeLimit(.minutes(1)))
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

    @Test("Tips load cheapest first, each with its store price", .enabled(SimulatorStoreKit.noProductsReason) { await SimulatorStoreKit.servesProducts() })
    func optionsLoadInPriceOrder() async throws {
        let session = try makeSession()
        defer { session.resetToDefaultState() }

        let options = try await StoreKitTipJar().options()

        #expect(options.map(\.tip) == [.small, .medium, .large])
        #expect(options.allSatisfy { !$0.displayPrice.isEmpty })
    }

    @Test(
        "A tip goes through and is thanked",
        .enabled(if: SimulatorStoreKit.purchasesWork, SimulatorStoreKit.skipReason),
        .enabled(SimulatorStoreKit.noProductsReason) { await SimulatorStoreKit.servesProducts() }
    )
    func tipIsThanked() async throws {
        let session = try makeSession()
        defer { session.resetToDefaultState() }
        let jar = StoreKitTipJar()
        _ = try await jar.options()

        #expect(try await jar.give(.small) == .thanked)
    }

    @Test(
        "Ask to Buy leaves the tip pending",
        .enabled(if: SimulatorStoreKit.purchasesWork, SimulatorStoreKit.skipReason),
        .enabled(SimulatorStoreKit.noProductsReason) { await SimulatorStoreKit.servesProducts() }
    )
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

// MARK: - SimulatorStoreKit

/// Where StoreKitTest works. Outside the suite: a trait can't read the type
/// its own macro is attached to.
nonisolated private enum SimulatorStoreKit {

    /// On the iOS 26 simulator StoreKitTest fails with SKInternalErrorDomain 3:
    /// products still load, but a purchase never returns.
    static var purchasesWork: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))
    }

    static let skipReason: Comment = "Purchases hang on the iOS 26 simulator; run on iOS 27"

    static let noProductsReason: Comment = "StoreKitTest serves no products in this environment (Xcode Cloud); run locally on iOS 27"

    /// Whether StoreKitTest serves the products Plekio.storekit declares. Xcode
    /// Cloud's simulators return none, so the tip tests can't run there. The ids
    /// come from the file, not from TipSize: a TipSize that drifts from the file
    /// still fails the tests instead of skipping them.
    static func servesProducts() async -> Bool {
        await probe.value
    }

    private static let probe = Task<Bool, Never> {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "Plekio", withExtension: "storekit"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(StoreKitFile.self, from: data),
              let session = try? SKTestSession(configurationFileNamed: "Plekio")
        else { return false }

        session.resetToDefaultState()
        let ids = file.products.map(\.productID)
        let products = (try? await Product.products(for: ids)) ?? []
        return Set(products.map(\.id)) == Set(ids)
    }

    private final class BundleToken {}

    private struct StoreKitFile: Decodable {
        struct Item: Decodable { let productID: String }
        let products: [Item]
    }
}
