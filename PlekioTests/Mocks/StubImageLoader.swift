//
//  StubImageLoader.swift
//  PlekioTests
//
//  ImageLoading that serves whatever a test put in it, and records what it
//  was asked for.
//

import UIKit
@testable import Plekio

nonisolated final class StubImageLoader: ImageLoading, @unchecked Sendable {
    var images: [UUID: UIImage] = [:]
    private(set) var requested: [UUID] = []

    func image(for id: UUID, targetPointSize: CGFloat?) async -> UIImage? {
        requested.append(id)
        return images[id]
    }
}
