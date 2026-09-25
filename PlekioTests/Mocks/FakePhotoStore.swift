//
//  FakePhotoStore.swift
//  PlekioTests
//
//  In-memory PhotoStoring, so nothing a test does lands in the app's real
//  photo folder.
//

import Foundation
@testable import Plekio

/// Remembers what it was asked to store, and can be told to refuse.
///
/// Locked: callers write from detached tasks, and a test may run two at once.
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
