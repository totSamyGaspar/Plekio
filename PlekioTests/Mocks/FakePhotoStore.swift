//
//  FakePhotoStore.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
@testable import Plekio

/// Records stored photos and can be told to refuse writes.
/// Locked: callers write from detached tasks, possibly concurrently.
nonisolated final class FakePhotoStore: PhotoStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var _saved: [UUID: Data] = [:]
    private var _deleted: [UUID] = []
    let refusesWrites: Bool

    var saved: [UUID: Data] { lock.withLock { _saved } }
    var deleted: [UUID] { lock.withLock { _deleted } }

    init(refusesWrites: Bool = false) {
        self.refusesWrites = refusesWrites
    }

    // MARK: - PhotoStoring

    func saveToDisk(_ data: Data, for id: UUID) -> Bool {
        guard !refusesWrites else { return false }
        lock.withLock { _saved[id] = data }
        return true
    }

    func loadDataFromDisk(for id: UUID) -> Data? { lock.withLock { _saved[id] } }

    func deleteFromDisk(for id: UUID) {
        lock.withLock {
            _saved[id] = nil
            _deleted.append(id)
        }
    }
}
