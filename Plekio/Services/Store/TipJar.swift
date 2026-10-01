//
//  TipJar.swift
//  Plekio
//
//  Created by Edward Gasparian on 30.09.2026.
//

import Foundation
import StoreKit

// MARK: - Tip

/// A one-off tip. Consumable: it can be given again and unlocks nothing, as App
/// Review expects of donations. Product ids are stored by App Store: never rename.
nonisolated enum TipSize: String, CaseIterable, Sendable {
    case small = "com.EdHasp.Plekio.tip.small"
    case medium = "com.EdHasp.Plekio.tip.medium"
    case large = "com.EdHasp.Plekio.tip.large"

    var title: LocalizedStringResource {
        switch self {
        case .small: "Small tip"
        case .medium: "Medium tip"
        case .large: "Large tip"
        }
    }
}

/// A tip as the store offers it: the price is already in the user's currency.
nonisolated struct TipOption: Identifiable, Equatable, Sendable {
    let tip: TipSize
    let displayPrice: String

    var id: TipSize { tip }
}

enum TipOutcome: Equatable {
    case thanked
    /// Ask to Buy or a payment that needs the bank: finished later via `Transaction.updates`.
    case pending
    case cancelled
}

// MARK: - TipJarService

@MainActor
protocol TipJarService: AnyObject {
    /// Cheapest first; empty when the store has none (offline, not set up).
    func options() async throws -> [TipOption]
    func give(_ tip: TipSize) async throws -> TipOutcome
}

// MARK: - StoreKitTipJar

/// StoreKit 2 with on-device verification: no server, like the rest of the app.
@MainActor
final class StoreKitTipJar: TipJarService {

    private var products: [TipSize: Product] = [:]

    /// Started at launch: a purchase interrupted earlier, or approved later
    /// through Ask to Buy, arrives here and must be finished.
    private let updates: Task<Void, Never>

    init() {
        updates = Task.detached {
            for await result in Transaction.unfinished { await Self.finish(result) }
            for await result in Transaction.updates { await Self.finish(result) }
        }
    }

    func options() async throws -> [TipOption] {
        let loaded = try await Product.products(for: TipSize.allCases.map(\.rawValue))
        products = Dictionary(uniqueKeysWithValues: loaded.compactMap { product in
            TipSize(rawValue: product.id).map { ($0, product) }
        })
        return loaded
            .sorted { $0.price < $1.price }
            .compactMap { product in
                TipSize(rawValue: product.id).map { TipOption(tip: $0, displayPrice: product.displayPrice) }
            }
    }

    func give(_ tip: TipSize) async throws -> TipOutcome {
        guard let product = products[tip] else { throw TipFailed.unavailable }

        switch try await product.purchase() {
        case .success(let verification):
            // Unverified means the receipt didn't check out: nothing to thank for.
            let transaction = try verification.payloadValue
            await transaction.finish()
            return .thanked
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// A tip unlocks nothing, so a verified transaction only has to be finished.
    private nonisolated static func finish(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
    }
}

// MARK: - TipFailed

nonisolated enum TipFailed: LocalizedError, AlertTitled {
    case unavailable

    var alertTitle: LocalizedStringResource { "Tip not sent" }

    var errorDescription: String? {
        String(localized: "The App Store isn't available right now. Please try again later.")
    }
}

#if DEBUG
// MARK: - PreviewTipJar

/// Fixed prices for previews; giving always succeeds.
final class PreviewTipJar: TipJarService {
    func options() async throws -> [TipOption] {
        [TipOption(tip: .small, displayPrice: "$0.99"),
         TipOption(tip: .medium, displayPrice: "$4.99"),
         TipOption(tip: .large, displayPrice: "$9.99")]
    }

    func give(_ tip: TipSize) async throws -> TipOutcome { .thanked }
}
#endif
