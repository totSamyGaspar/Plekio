//
//  ReportStyle.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import UIKit

/// Page geometry, fonts and colours for the exported PDF.
/// Always black on white, never the app palette: documents get printed.
nonisolated struct ReportStyle {

    // MARK: - Page

    /// A4 in PDF points (72 per inch).
    let pageSize = CGSize(width: 595, height: 842)
    let margin: CGFloat = 48

    /// Room kept at the foot of every page for the page number.
    let footerHeight: CGFloat = 28

    /// Below this remaining height a new block starts on the next page.
    let minimumBlockHeight: CGFloat = 40

    // MARK: - Type

    let title = ReportStyle.serif(24, .bold)
    let heading = ReportStyle.serif(16, .bold)
    let subheading = UIFont.systemFont(ofSize: 12, weight: .semibold)
    let body = UIFont.systemFont(ofSize: 11, weight: .regular)
    let caption = UIFont.systemFont(ofSize: 9, weight: .regular)
    let tableHeader = UIFont.systemFont(ofSize: 9, weight: .semibold)

    static func serif(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    // MARK: - Ink

    let ink = UIColor.black
    let secondaryInk = UIColor(white: 0.35, alpha: 1)
    let mutedInk = UIColor(white: 0.55, alpha: 1)
    let rule = UIColor(white: 0.82, alpha: 1)

    /// Hard-coded accent: the palette colour varies with dark mode.
    let accent = UIColor(red: 0.05, green: 0.78, blue: 0.65, alpha: 1)

    // MARK: - Rhythm

    let paragraphGap: CGFloat = 6
    let sectionGap: CGFloat = 18
    let rowGap: CGFloat = 3
}
