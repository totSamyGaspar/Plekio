//
//  ReportDocument.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import Foundation
import PDFKit

/// Turns rendered PDF bytes into a file: metadata, bookmark outline and the write.
/// Drawing stays in UIKit; PDFKit can only create pages from images.
nonisolated enum ReportDocument {

    // MARK: - Types

    enum Failure: Error {
        case unreadable
        case notWritten
    }

    // MARK: - Public

    /// Writes the report to `directory` and returns the file URL for sharing.
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

        // Some readers show an empty author field, so omit it rather than leave it blank.
        if !data.profile.name.isEmpty {
            attributes[PDFDocumentAttribute.authorAttribute] = data.profile.name
        }
        return attributes
    }

    private static func title(for data: ReportData) -> String {
        let day = Date.FormatStyle.dateTime.day().month(.abbreviated).year()
        return "\(String(localized: "Health report")) · \(data.from.formatted(day)) — \(data.to.formatted(day))"
    }

    /// ISO dates: sort correctly in a folder and read the same in every locale.
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
