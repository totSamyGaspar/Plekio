//
//  PhotoStoring.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

nonisolated protocol PhotoStoring: Sendable {
    /// Returns whether the bytes reached disk.
    @discardableResult
    func saveToDisk(_ data: Data, for id: UUID) -> Bool
    func loadDataFromDisk(for id: UUID) -> Data?
    func deleteFromDisk(for id: UUID)
}

// MARK: - ImageCache

extension ImageCache: PhotoStoring {}
