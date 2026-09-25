//
//  PageCanvasTests.swift
//  PlekioTests
//
//  The page-break arithmetic, checked through the file that actually comes out
//  rather than through the numbers on the way in. PDFKit reads the text back,
//  which incidentally proves the document carries text and not a picture of it:
//  a report a doctor cannot select or search would be a regression nothing else
//  here would notice.
//

import Testing
import Foundation
import PDFKit
import UIKit
@testable import Plekio

@MainActor
@Suite("PageCanvas")
struct PageCanvasTests {

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
        let sentence = "Пацієнт приймав призначені препарати за розкладом і вів щоденник самопочуття. "
        return "НАЧАЛО " + String(repeating: sentence, count: 200) + marker
    }

    @Test("написанное читается обратно как текст, а не как картинка")
    func testTextStaysText() async throws {
        let document = try render { canvas in
            canvas.write("Ибупрофен 200 мг", font: style.body)
        }

        #expect(document.pageCount == 1)
        #expect(document.string?.contains("Ибупрофен 200 мг") == true)
    }

    // The reason text goes through CoreText: UIKit's draw would fit what it
    // could into the rect and quietly drop the rest.
    @Test("длинный текст переносится на следующие страницы, а не обрезается")
    func testLongTextFlowsOntoFurtherPages() async throws {
        let document = try render { canvas in
            canvas.write(self.longText(marker: "КОНЕЦ"), font: style.body)
        }

        #expect(document.pageCount > 1)

        let first = try #require(document.page(at: 0)?.string)
        let last = try #require(document.page(at: document.pageCount - 1)?.string)

        #expect(first.contains("НАЧАЛО"))
        #expect(last.contains("КОНЕЦ"))
    }

    @Test("блок, которому не хватает места, переезжает на новую страницу целиком")
    func testReserveMovesABlockToTheNextPage() async throws {
        let document = try render { canvas in
            canvas.write("Шапка", font: style.body)

            // More than is left, so the next block cannot start here.
            canvas.reserve(canvas.remaining + 1)
            canvas.write("Перенесённый блок", font: style.body)
        }

        #expect(document.pageCount == 2)
        #expect(document.page(at: 0)?.string?.contains("Шапка") == true)
        #expect(document.page(at: 0)?.string?.contains("Перенесённый блок") == false)
        #expect(document.page(at: 1)?.string?.contains("Перенесённый блок") == true)
    }

    // reserve is for keeping a heading with its content; on an empty page it
    // must not add a blank one before it.
    @Test("резерв на пустой странице не плодит пустую страницу перед блоком")
    func testReserveDoesNotBlankPageWhenNothingIsWrittenYet() async throws {
        let document = try render { canvas in
            canvas.reserve(canvas.remaining + 1)
            canvas.write("Первый блок", font: style.body)
        }

        #expect(document.pageCount == 1)
    }

    @Test("строка таблицы пишет все свои ячейки")
    func testRowWritesEveryCell() async throws {
        let document = try render { canvas in
            canvas.row(
                [("02.06.2026", 0), ("120/80", 200), ("Пульс 64", 320)],
                font: style.body
            )
        }

        let text = try #require(document.string)
        #expect(text.contains("02.06.2026"))
        #expect(text.contains("120/80"))
        #expect(text.contains("Пульс 64"))
    }
}
