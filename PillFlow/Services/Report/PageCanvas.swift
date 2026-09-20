//
//  PageCanvas.swift
//  PillFlow
//

import CoreText
import UIKit

/// Writes down a page and starts a new one when it runs out.
///
/// The one piece of the export that knows about page breaks. Sections above it
/// ask for text, a rule or a gap and never count millimetres; the renderer
/// below it only opens and closes the document.
///
/// Text goes through CoreText rather than `NSAttributedString.draw(in:)`
/// because a block has to be able to end mid-paragraph and continue overleaf —
/// a long diary note is exactly the thing that does not fit in what is left of
/// a page, and UIKit's draw would silently clip it.
final class PageCanvas {

    private let context: UIGraphicsPDFRendererContext
    let style: ReportStyle

    /// Zero-based, so it can be handed straight to `PDFDocument.page(at:)` when
    /// the outline is built.
    private(set) var pageIndex = -1

    private var cursor: CGFloat = 0

    init(context: UIGraphicsPDFRendererContext, style: ReportStyle) {
        self.context = context
        self.style = style
        beginPage()
    }

    // MARK: - Geometry

    var contentWidth: CGFloat { style.pageSize.width - style.margin * 2 }

    private var floor: CGFloat { style.pageSize.height - style.margin - style.footerHeight }

    var remaining: CGFloat { floor - cursor }

    /// True when nothing has been written on the page yet, which is how the
    /// text loop tells "does not fit here" from "does not fit anywhere".
    private var isPageEmpty: Bool { cursor == style.margin }

    // MARK: - Pages

    func beginPage() {
        context.beginPage()
        pageIndex += 1
        cursor = style.margin
        drawFooter()
    }

    /// Starts a new page if `height` would not fit on this one. Used to keep a
    /// heading attached to the first line of what it introduces.
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
                // Nothing fits even on a page of its own: one line taller than
                // the text area. Stop rather than loop forever on it.
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

    /// Draws at the given height, keeping the image's proportions, and moves
    /// the cursor past it like any other block.
    func image(_ image: UIImage, height: CGFloat, x: CGFloat? = nil, gap: CGFloat = 0) {
        reserve(height)

        let width = height * (image.size.width / max(image.size.height, 1))
        image.draw(in: CGRect(x: x ?? style.margin, y: cursor, width: width, height: height))

        cursor += height
        space(gap)
    }

    // MARK: - CoreText

    /// CoreText measures from the bottom left and UIKit hands us a context
    /// flipped the other way, so the frame is drawn through an inverted
    /// transform and the rect mirrored about the middle of the page.
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

extension PageCanvas {

    /// The attributed string a caller would otherwise build by hand at every
    /// call site, with the paragraph spacing the document is set in.
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

    /// A row of cells at fixed left offsets — the one shape a table needs, and
    /// cheaper than a layout engine for three columns of numbers.
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
