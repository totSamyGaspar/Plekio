//
//  TestImages.swift
//  PlekioTests
//
//  A real bitmap for tests that encode images. `UIImage(systemName:)` is a
//  symbol, and `UIImage()` has nothing behind it at all — neither says anything
//  about how a photo from the camera is handled.
//

import UIKit

enum TestImages {

    /// A small opaque image with a CGImage behind it, like a decoded photo.
    static func solid(_ color: UIColor = .systemTeal, size: CGSize = CGSize(width: 8, height: 8)) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
