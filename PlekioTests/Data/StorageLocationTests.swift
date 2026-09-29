//
//  StorageLocationTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 29.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@Suite("Storage location")
struct StorageLocationTests {

    @Test("Every file lives under the root, which exists after init")
    func pathsLiveUnderTheRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "StorageLocationTests-\(UUID().uuidString)/Nested", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }

        let location = StorageLocation(root: root)

        #expect(FileManager.default.fileExists(atPath: root.path))
        #expect(location.storeURL == root.appending(path: "Plekio.store"))
        #expect(location.photosDirectory.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL)
    }

    @Test("The app's location is in the App Group container")
    func sharedLocationIsInTheAppGroup() throws {
        let container = try #require(
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: StorageLocation.appGroupId)
        )
        #expect(StorageLocation.appGroup().storeURL.path.hasPrefix(container.path))
    }
}
