//
//  PageCanvas.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import CoreText
import UIKit

/// Lays blocks down a PDF page and breaks to a new page when it runs out.
/// Uses CoreText so text can split mid-paragraph across pages instead of being clipped.
nonisolated final class PageCanvas {

    // MARK: - Properties

    private let context: UIGraphicsPDFRendererContext
    let style: ReportStyle

    /// Zero-based, matching `PDFDocument.page(at:)`.
    private(set) var pageIndex = -1

    private var cursor: CGFloat = 0

    // MARK: - Init

    init(context: UIGraphicsPDFRendererContext, style: ReportStyle) {
        self.context = context
        self.style = style
        beginPage()
    }

    // MARK: - Geometry

    var contentWidth: CGFloat { style.pageSize.width - style.margin * 2 }

    private var floor: CGFloat { style.pageSize.height - style.margin - style.footerHeight }

    var remaining: CGFloat { floor - cursor }

    /// True before anything is written on the page; tells "not here" from "nowhere".
    private var isPageEmpty: Bool { cursor == style.margin }

    // MARK: - Pages

    func beginPage() {
        context.beginPage()
        pageIndex += 1
        cursor = style.margin
        drawFooter()
    }

    /// Starts a new page if `height` would not fit, e.g. to keep a heading with its content.
    func reserve(_ height: CGFloat) {
        guard !isPageEmpty, height > remaining else { return }
        beginPage()
    }

    func space(_ height: CGFloat) {
        cursor = min(cursor + height, floor)
    }

    // MARK: - Drawing

    /// Writes the text and returns the page its first line landed on.
    @discardableResult
    func write(_ text: NSAttributedString, indent: CGFloat = 0, gap: CGFloat = 0) -> Int {
        guard text.length > 0 else { return pageIndex }

        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let width = contentWidth - indent
        let startedOn = pageIndex
        var drawn = 0

        while drawn < text.length {
            if remaining < style.minimumBlockHeight, !isPageEmpty { beginPage() }

            var fitted = CFRange()
            let size = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter,
                CFRange(location: drawn, length: 0),
                nil,
                CGSize(width: width, height: remaining),
                &fitted
            )

            guard fitted.length > 0 else {
                // Taller than an empty page: stop rather than loop forever.
                if isPageEmpty { break }
                beginPage()
                continue
            }

            draw(
                framesetter,
                range: CFRange(location: drawn, length: fitted.length),
                in: CGRect(x: style.margin + indent, y: cursor, width: width, height: ceil(size.height))
            )

            cursor += ceil(size.height)
            drawn += fitted.length
        }

        space(gap)
        return startedOn
    }

    func rule(indent: CGFloat = 0) {
        reserve(1)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: style.margin + indent, y: cursor))
        path.addLine(to: CGPoint(x: style.pageSize.width - style.margin, y: cursor))

        style.rule.setStroke()
        path.lineWidth = 0.5
        path.stroke()

        cursor += 1
    }

    /// Draws at `height`, keeping the aspect ratio, and advances the cursor.
    func image(_ image: UIImage, height: CGFloat, x: CGFloat? = nil, gap: CGFloat = 0) {
        reserve(height)

        let width = height * (image.size.width / max(image.size.height, 1))
        image.draw(in: CGRect(x: x ?? style.margin, y: cursor, width: width, height: height))

        cursor += height
        space(gap)
    }

    /// An image with a line of text beside it, vertically centred on each other.
    func imageRow(
        _ image: UIImage,
        height: CGFloat,
        text: NSAttributedString,
        spacing: CGFloat = 10,
        gap: CGFloat = 0
    ) {
        let textSize = text.size()
        let rowHeight = max(height, ceil(textSize.height))
        reserve(rowHeight)

        let width = height * (image.size.width / max(image.size.height, 1))
        image.draw(in: CGRect(
            x: style.margin,
            y: cursor + (rowHeight - height) / 2,
            width: width,
            height: height
        ))

        text.draw(at: CGPoint(
            x: style.margin + width + spacing,
            y: cursor + (rowHeight - textSize.height) / 2
        ))

        cursor += rowHeight
        space(gap)
    }

    // MARK: - CoreText

    /// Flips the UIKit context and rect for CoreText's bottom-left origin.
    private func draw(_ framesetter: CTFramesetter, range: CFRange, in rect: CGRect) {
        let cg = context.cgContext

        cg.saveGState()
        cg.textMatrix = .identity
        cg.translateBy(x: 0, y: style.pageSize.height)
        cg.scaleBy(x: 1, y: -1)

        let flipped = CGRect(
            x: rect.minX,
            y: style.pageSize.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )

        let frame = CTFramesetterCreateFrame(framesetter, range, CGPath(rect: flipped, transform: nil), nil)
        CTFrameDraw(frame, cg)

        cg.restoreGState()
    }

    private func drawFooter() {
        let number = NSAttributedString(
            string: "\(pageIndex + 1)",
            attributes: [.font: style.caption, .foregroundColor: style.mutedInk]
        )

        let size = number.size()
        number.draw(at: CGPoint(
            x: (style.pageSize.width - size.width) / 2,
            y: style.pageSize.height - style.margin - size.height
        ))
    }
}

// MARK: - Text

// `nonisolated` again: extensions default to MainActor in this module.
nonisolated extension PageCanvas {

    /// An attributed string in the document's paragraph style.
    func text(
        _ string: String,
        font: UIFont,
        color: UIColor? = nil,
        alignment: NSTextAlignment = .natural
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping

        return NSAttributedString(
            string: string,
            attributes: [
                .font: font,
                .foregroundColor: color ?? style.ink,
                .paragraphStyle: paragraph
            ]
        )
    }

    @discardableResult
    func write(
        _ string: String,
        font: UIFont,
        color: UIColor? = nil,
        indent: CGFloat = 0,
        gap: CGFloat = 0
    ) -> Int {
        write(text(string, font: font, color: color), indent: indent, gap: gap)
    }

    /// A single-line row of cells at fixed left offsets.
    func row(_ cells: [(text: String, x: CGFloat)], font: UIFont, color: UIColor? = nil, gap: CGFloat = 0) {
        let height = ceil(font.lineHeight)
        reserve(height)

        for cell in cells {
            text(cell.text, font: font, color: color)
                .draw(at: CGPoint(x: style.margin + cell.x, y: cursor))
        }

        cursor += height
        space(gap)
    }
}
