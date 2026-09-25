//
//  TestImages.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import UIKit

// MARK: - TestImages

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
