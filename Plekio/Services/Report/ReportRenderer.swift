//
//  ReportRenderer.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import UIKit

// MARK: - ReportBranding

/// The app's logo and name for the report header, kept apart from user data.
nonisolated struct ReportBranding {

    let logo: UIImage?
    let appName: String

    /// `logo` is nil when the asset is missing; the header then shows the name alone.
    static var app: ReportBranding {
        ReportBranding(logo: UIImage(named: AppBrand.logoAssetName), appName: AppBrand.name)
    }
}

// MARK: - RenderedReport

nonisolated struct RenderedReport {

    let data: Data

    /// Page index where each section begins, collected while drawing.
    let bookmarks: [Bookmark]

    struct Bookmark: Equatable {
        let title: String
        let page: Int
    }
}

// MARK: - ReportRenderer

/// Draws `ReportData` into PDF bytes; no SwiftData or sharing, so it is testable.
/// Nonisolated so long reports render off the main actor.
nonisolated struct ReportRenderer {

    // MARK: - Properties

    private let style: ReportStyle
    private let branding: ReportBranding

    init(style: ReportStyle = ReportStyle(), branding: ReportBranding = .app) {
        self.style = style
        self.branding = branding
    }

    // MARK: - Render

    /// `photos` must be pre-loaded by the caller: loading is async, drawing is not.
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

    /// `withTintColor` paints the whole frame solid in a PDF context, so tint by
    /// compositing with `.sourceIn` instead.
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

    /// Skipped for an empty profile. Age is as of the report date, not today.
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
