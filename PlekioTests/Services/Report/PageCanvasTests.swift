//
//  PageCanvasTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 19.09.2026.
//

import Testing
import Foundation
import PDFKit
import UIKit
@testable import Plekio

@MainActor
@Suite("PageCanvas")
struct PageCanvasTests {

    // MARK: - Helpers

    private let style = ReportStyle()

    private func render(_ draw: (PageCanvas) -> Void) throws -> PDFDocument {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: style.pageSize))
        let data = renderer.pdfData { context in
            draw(PageCanvas(context: context, style: style))
        }
        return try #require(PDFDocument(data: data))
    }

    /// Long enough to overflow a page several times over.
    private func longText(marker: String) -> String {
        let sentence = "The patient took the prescribed medications on schedule and kept a well-being diary. "
        return "START " + String(repeating: sentence, count: 200) + marker
    }

    // MARK: - Text

    @Test("Written text reads back as text, not as an image")
    func testTextStaysText() async throws {
        let document = try render { canvas in
            canvas.write("Ibuprofen 200 mg", font: style.body)
        }

        #expect(document.pageCount == 1)
        #expect(document.string?.contains("Ibuprofen 200 mg") == true)
    }

    // The only non-English data in the suite: the report must print every supported script.
    @Test("Cyrillic and Japanese text reads back as text", arguments: ["Ибупрофен 200 мг", "Пеніцилін", "イブプロフェン"])
    func testNonLatinTextStaysText(sample: String) async throws {
        let document = try render { canvas in
            canvas.write(sample, font: style.body)
        }

        #expect(document.string?.contains(sample) == true)
    }

    // Text goes through CoreText because UIKit's draw silently truncates to the rect.
    @Test("Long text flows onto following pages instead of being cut")
    func testLongTextFlowsOntoFurtherPages() async throws {
        let document = try render { canvas in
            canvas.write(self.longText(marker: "END"), font: style.body)
        }

        #expect(document.pageCount > 1)

        let first = try #require(document.page(at: 0)?.string)
        let last = try #require(document.page(at: document.pageCount - 1)?.string)

        #expect(first.contains("START"))
        #expect(last.contains("END"))
    }

    // MARK: - Page breaks

    @Test("A block that doesn't fit moves to a new page whole")
    func testReserveMovesABlockToTheNextPage() async throws {
        let document = try render { canvas in
            canvas.write("Header", font: style.body)

            // More than is left, so the next block cannot start here.
            canvas.reserve(canvas.remaining + 1)
            canvas.write("Moved block", font: style.body)
        }

        #expect(document.pageCount == 2)
        #expect(document.page(at: 0)?.string?.contains("Header") == true)
        #expect(document.page(at: 0)?.string?.contains("Moved block") == false)
        #expect(document.page(at: 1)?.string?.contains("Moved block") == true)
    }

    @Test("Reserving space on an empty page doesn't add a blank page before the block")
    func testReserveDoesNotBlankPageWhenNothingIsWrittenYet() async throws {
        let document = try render { canvas in
            canvas.reserve(canvas.remaining + 1)
            canvas.write("First block", font: style.body)
        }

        #expect(document.pageCount == 1)
    }

    // MARK: - Rows

    @Test("A table row writes all its cells")
    func testRowWritesEveryCell() async throws {
        let document = try render { canvas in
            canvas.row(
                [("02.06.2026", 0), ("120/80", 200), ("Pulse 64", 320)],
                font: style.body
            )
        }

        let text = try #require(document.string)
        #expect(text.contains("02.06.2026"))
        #expect(text.contains("120/80"))
        #expect(text.contains("Pulse 64"))
    }
}
