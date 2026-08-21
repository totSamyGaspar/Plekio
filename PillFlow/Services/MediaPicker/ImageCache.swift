//
//  ImageCache.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.06.2026.
//

import UIKit

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100
    }
    
    func set(_ image: UIImage, forKey key: UUID) {
        cache.setObject(image, forKey: key.uuidString as NSString)
    }
    
    func get(forKey key: UUID) -> UIImage? {
        return cache.object(forKey: key.uuidString as NSString)
    }
    
    // MARK: - Helper
    
    func image(for id: UUID, data: Data?) -> UIImage? {
        if let cached = get(forKey: id) { return cached }
        guard let data, let image = UIImage(data: data) else { return nil }
        set(image, forKey: id)
        return image
    }
}
