//
//  PhotoStoring.swift
//  Plekio
//
//  The part of the photo store the database needs: files keyed by the id of the
//  record they belong to. The storage layer depends on this, not on ImageCache,
//  so it can be handed a store in a temporary directory — and a test of the
//  database no longer has to write into the app's real photo folder.
//

import Foundation

nonisolated protocol PhotoStoring: Sendable {
    /// Returns whether the bytes reached disk.
    @discardableResult
    func saveToDisk(_ data: Data, for id: UUID) -> Bool
    func loadDataFromDisk(for id: UUID) -> Data?
    func deleteFromDisk(for id: UUID)
}

extension ImageCache: PhotoStoring {}
