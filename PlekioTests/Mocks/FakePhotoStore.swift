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
nonisolated final class FakePhotoStore: PhotoStoring, @unchecked Sendable {
    private(set) var saved: [UUID: Data] = [:]
    private(set) var deleted: [UUID] = []
    let refusesWrites: Bool

    init(refusesWrites: Bool = false) {
        self.refusesWrites = refusesWrites
    }

    func saveToDisk(_ data: Data, for id: UUID) -> Bool {
        guard !refusesWrites else { return false }
        saved[id] = data
        return true
    }

    func loadDataFromDisk(for id: UUID) -> Data? { saved[id] }

    func deleteFromDisk(for id: UUID) {
        saved[id] = nil
        deleted.append(id)
    }
}
