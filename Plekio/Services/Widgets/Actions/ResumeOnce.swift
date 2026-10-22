//
//  ResumeOnce.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

// MARK: - ResumeOnce

/// A continuation resumed by whichever comes first; later calls do nothing.
@MainActor
final class ResumeOnce {
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func callAsFunction() {
        continuation?.resume()
        continuation = nil
    }
}
