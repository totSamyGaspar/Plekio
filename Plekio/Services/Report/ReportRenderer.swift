//
//  ReportRenderer.swift
//  Plekio
//

import UIKit

/// The app's own mark on the document, kept apart from the user's data.
///
/// `ReportData` carries what the user recorded; this carries what the app puts
/// on it. Mixing the two would mean the builder had to know about assets.
nonisolated struct ReportBranding {

    let logo: UIImage?
    let appName: String

    /// Nil until an image set named `Logo` exists in the asset catalog. The
    /// header sets the mark beside the wordmark, so a build without the image
    /// set loses the mark and keeps the name rather than losing both.
    static var app: ReportBranding {
        ReportBranding(logo: UIImage(named: AppBrand.logoAssetName), appName: AppBrand.name)
    }
}

nonisolated struct RenderedReport {

    let data: Data

    /// Where each section begins, collected while drawing. Searching the
    /// finished file for its own headings would be both slower and a guess.
    let bookmarks: [Bookmark]

    struct Bookmark: Equatable {
        let title: String
        let page: Int
    }
}

/// Draws a report into PDF bytes.
///
/// Knows nothing about SwiftData and nothing about sharing: values in, bytes
/// out. That is what lets the layout be exercised in tests against made-up
/// data, without a store and without a share sheet.
///
/// `nonisolated`, with everything it draws with: rendering a few months with
/// photos is many pages, and it runs off the main actor so the export screen
/// stays responsive while it does.
nonisolated struct ReportRenderer {

    private let style: ReportStyle
    private let branding: ReportBranding

    init(style: ReportStyle = ReportStyle(), branding: ReportBranding = .app) {
        self.style = style
        self.branding = branding
    }

    /// `photos` is resolved by the caller: reading them is asynchronous and
    /// drawing is not, so the pictures arrive already decoded rather than the
    /// renderer waiting on a cache mid-page.
    func render(_ data: ReportData, photos: [UUID: UIImage] = [:]) -> RenderedReport {
        var bookmarks: [RenderedReport.Bookmark] = []

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: style.pageSize)
        )

        let bytes = renderer.pdfData { context in
            let canvas = PageCanvas(context: context, style: style)
            let sections = ReportSections(canvas: canvas, photos: photos)

            header(on: canvas, data: data)

            if !data.courses.isEmpty {
                bookmarks.append(.init(
                    title: String(localized: "Medications"),
                    page: sections.medications(data.courses)
                ))
            }
            if !data.pressure.isEmpty {
                bookmarks.append(.init(
                    title: String(localized: "Blood Pressure"),
                    page: sections.pressure(data.pressure)
                ))
            }
            if !data.diary.isEmpty {
                bookmarks.append(.init(
                    title: String(localized: "Diary"),
                    page: sections.diary(data.diary)
                ))
            }
            if data.isEmpty {
                canvas.write(
                    String(localized: "No records for the selected period"),
                    font: style.body,
                    color: style.mutedInk
                )
            }
        }

        return RenderedReport(data: bytes, bookmarks: bookmarks)
    }

    // MARK: - Header

    /// `withTintColor` is meant for a template image on its way into a view;
    /// asked for one inside a PDF context it painted the whole frame solid
    /// instead of the mark. So the colour is composited here: draw the
    /// artwork, then fill only the pixels it left opaque.
    private func tinted(_ image: UIImage, _ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: image.size).image { context in
            image.draw(at: .zero)
            color.setFill()
            context.fill(CGRect(origin: .zero, size: image.size), blendMode: .sourceIn)
        }
    }

    private func header(on canvas: PageCanvas, data: ReportData) {
        let wordmark = canvas.text(
            branding.appName,
            font: ReportStyle.serif(18, .bold),
            color: style.accent
        )

        if let logo = branding.logo {
            canvas.imageRow(tinted(logo, style.accent), height: 22, text: wordmark, gap: 10)
        } else {
            canvas.write(wordmark, gap: 10)
        }

        canvas.write(String(localized: "Health report"), font: style.title, gap: 4)

        let day = Date.FormatStyle.dateTime.day().month(.abbreviated).year()
        canvas.write(
            "\(data.from.formatted(day)) — \(data.to.formatted(day))",
            font: style.body,
            color: style.secondaryInk,
            gap: 2
        )
        canvas.write(
            data.generatedAt.formatted(day),
            font: style.caption,
            color: style.mutedInk,
            gap: 12
        )

        patient(on: canvas, profile: data.profile, on: data.generatedAt)

        canvas.rule()
        canvas.space(style.sectionGap)
    }

    /// Skipped entirely for an empty profile: a header of blank labels says
    /// less than no header at all.
    ///
    /// The age is stated as of the day the document was made, not as of now —
    /// a report from last spring should keep saying what it said then.
    private func patient(on canvas: PageCanvas, profile: UserProfile, on date: Date) {
        guard !profile.isEmpty else { return }

        if !profile.name.isEmpty {
            canvas.write(profile.name, font: style.heading, gap: 3)
        }

        let day = Date.FormatStyle.dateTime.day().month(.abbreviated).year()

        if let birthDate = profile.birthDate {
            var line = "\(String(localized: "Date of birth")): \(birthDate.formatted(day))"
            if let age = profile.age(on: date) {
                line += " (\(age))"
            }
            canvas.write(line, font: style.body, color: style.secondaryInk, gap: 2)
        }

        for (label, value) in [
            (String(localized: "Allergies"), profile.allergies),
            (String(localized: "Chronic conditions"), profile.conditions)
        ] where !value.isEmpty {
            canvas.write("\(label): \(value)", font: style.body, color: style.secondaryInk, gap: 2)
        }

        canvas.space(8)
    }

}
