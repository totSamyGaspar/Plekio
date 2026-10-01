import Testing
import Foundation
import PDFKit
import UIKit
@testable import Plekio

@MainActor
@Suite("ReportDocument")
struct ReportDocumentTests {
    @Test("Written bookmarks retain their labels and target pages, including shared pages")
    func bookmarksSurviveWriting() throws {
        let bookmarks: [RenderedReport.Bookmark] = [
            .init(title: "Medications", page: 0),
            .init(title: "Blood Pressure", page: 0),
            .init(title: "Diary", page: 1)
        ]
        try withWrittenReport(bookmarks: bookmarks) { document in
            #expect(document.pageCount == 2)
            let root = try #require(document.outlineRoot)
            #expect(root.numberOfChildren == bookmarks.count)
            for (index, bookmark) in bookmarks.enumerated() {
                let child = try #require(root.child(at: index))
                #expect(child.label == bookmark.title)
                let page = try #require(child.destination?.page)
                #expect(document.index(for: page) == bookmark.page)
            }
            #expect(document.string?.contains("First page") == true)
            #expect(document.string?.contains("Second page") == true)
        }
    }

    @Test("A report without bookmarks has no outline")
    func noBookmarks() throws {
        try withWrittenReport(bookmarks: []) { document in
            #expect(document.outlineRoot == nil)
            #expect(document.pageCount == 2)
        }
    }

    @Test("Invalid bookmark pages are skipped without displacing valid bookmarks")
    func invalidBookmarkPages() throws {
        try withWrittenReport(bookmarks: [
            .init(title: "Invalid negative page", page: -1),
            .init(title: "First", page: 0),
            .init(title: "Past the last page", page: 2),
            .init(title: "Second", page: 1)
        ]) { document in
            let root = try #require(document.outlineRoot)
            #expect(root.numberOfChildren == 2)
            #expect(root.child(at: 0)?.label == "First")
            #expect(root.child(at: 1)?.label == "Second")
        }
    }

    private func withWrittenReport(
        bookmarks: [RenderedReport.Bookmark],
        check: (PDFDocument) throws -> Void
    ) throws {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let bytes = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for text in ["First page", "Second page"] {
                context.beginPage()
                (text as NSString).draw(
                    at: CGPoint(x: 40, y: 40),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 16)]
                )
            }
        }
        let date = testDate(2026, 6, 1)
        let data = ReportData(
            profile: .empty, from: date, to: date, generatedAt: date,
            courses: [], pressure: [], diary: []
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReportDocumentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try ReportDocument.write(
            RenderedReport(data: bytes, bookmarks: bookmarks), for: data, in: directory
        )
        let reopened = try #require(PDFDocument(url: url))
        try check(reopened)
    }
}
