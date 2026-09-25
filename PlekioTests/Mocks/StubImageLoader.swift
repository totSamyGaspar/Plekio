//
//  StubImageLoader.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import UIKit
@testable import Plekio

// MARK: - StubImageLoader

nonisolated final class StubImageLoader: ImageLoading, @unchecked Sendable {
    var images: [UUID: UIImage] = [:]
    private(set) var requested: [UUID] = []

    func image(for id: UUID, targetPointSize: CGFloat?) async -> UIImage? {
        requested.append(id)
        return images[id]
    }
}
