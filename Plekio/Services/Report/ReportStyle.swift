//
//  ReportStyle.swift
//  Plekio
//

import UIKit

/// Page geometry, type and colour for an exported document.
///
/// Deliberately not built from the app's palette. The app is dark; a document
/// is printed, forwarded and read in a mail client, so it is black on white
/// whatever theme the phone is in. Pulling `Color.appBackground` in here would
/// produce a report that comes out of a printer as a solid dark rectangle.
///
/// Left on the main actor for now, along with the canvas: whether UIKit's font
/// and PDF renderer types are main-actor isolated under this SDK is a question
/// worth answering by building rather than by guessing. Moving the render off
/// it is a later, measured step — `ReportData` is already nonisolated, which is
/// the half that matters for crossing over.
nonisolated struct ReportStyle {

    /// A4 at 72 points to the inch, which is the unit a PDF context works in.
    let pageSize = CGSize(width: 595, height: 842)
    let margin: CGFloat = 48

    /// Room kept at the foot of every page for the page number.
    let footerHeight: CGFloat = 28

    /// Less space than this at the bottom is not worth starting a block in.
    let minimumBlockHeight: CGFloat = 40

    // MARK: - Type

    /// Serif for headings, matching the screen titles in the app.
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

    /// The app's accent, spelled out rather than read from the palette: the
    /// palette answers differently in dark mode, and a document has no mode.
    let accent = UIColor(red: 0.05, green: 0.78, blue: 0.65, alpha: 1)

    // MARK: - Rhythm

    let paragraphGap: CGFloat = 6
    let sectionGap: CGFloat = 18
    let rowGap: CGFloat = 3
}
