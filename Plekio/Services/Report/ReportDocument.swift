//
//  ReportDocument.swift
//  Plekio
//

import Foundation
import PDFKit

/// Finishes the drawn bytes into a file worth sending.
///
/// This is the half PDFKit is genuinely for. It cannot draw a page of text —
/// its only content-bearing page initialiser takes a `UIImage`, which would
/// turn the whole report into a picture — but it owns everything that happens
/// to a document once the pages exist: the metadata a mail client shows instead
/// of "Untitled", the bookmark tree that lets a reader jump to a section, and
/// the write itself.
nonisolated enum ReportDocument {

    enum Failure: Error {
        case unreadable
        case notWritten
    }

    /// Writes the report into the temporary directory and returns its URL,
    /// ready for a share sheet.
    ///
    /// The file name carries the period, because it is what the recipient sees
    /// in an attachment list and in their downloads folder.
    static func write(
        _ report: RenderedReport,
        for data: ReportData,
        in directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        guard let document = PDFDocument(data: report.data) else {
            throw Failure.unreadable
        }

        document.documentAttributes = attributes(for: data)
        document.outlineRoot = outline(report.bookmarks, in: document)

        let url = directory.appendingPathComponent(fileName(for: data))

        guard document.write(to: url) else { throw Failure.notWritten }
        return url
    }

    // MARK: - Metadata

    private static func attributes(for data: ReportData) -> [AnyHashable: Any] {
        var attributes: [AnyHashable: Any] = [
            PDFDocumentAttribute.titleAttribute: title(for: data),
            PDFDocumentAttribute.creatorAttribute: ReportBranding.app.appName,
            PDFDocumentAttribute.creationDateAttribute: data.generatedAt
        ]

        // The patient's name as the author, when there is one. An empty author
        // is worse than none: some readers show the field regardless.
        if !data.profile.name.isEmpty {
            attributes[PDFDocumentAttribute.authorAttribute] = data.profile.name
        }
        return attributes
    }

    private static func title(for data: ReportData) -> String {
        let day = Date.FormatStyle.dateTime.day().month(.abbreviated).year()
        return "\(String(localized: "Health report")) · \(data.from.formatted(day)) — \(data.to.formatted(day))"
    }

    /// ISO dates in the file name: year first sorts correctly in a folder, and
    /// it is the one ordering no locale rearranges. A localised date here would
    /// put the day first for some recipients and the month first for others.
    private static func fileName(for data: ReportData) -> String {
        let day = Date.ISO8601FormatStyle(timeZone: .current)
            .year().month().day().dateSeparator(.dash)

        return "\(AppBrand.name) \(data.from.formatted(day)) — \(data.to.formatted(day)).pdf"
    }

    // MARK: - Outline

    private static func outline(_ bookmarks: [RenderedReport.Bookmark], in document: PDFDocument) -> PDFOutline? {
        guard !bookmarks.isEmpty else { return nil }

        let root = PDFOutline()

        for (index, bookmark) in bookmarks.enumerated() {
            guard let page = document.page(at: bookmark.page) else { continue }

            let child = PDFOutline()
            child.label = bookmark.title
            child.destination = PDFDestination(page: page, at: CGPoint(x: 0, y: page.bounds(for: .mediaBox).height))

            root.insertChild(child, at: index)
        }

        return root.numberOfChildren > 0 ? root : nil
    }
}
