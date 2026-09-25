//
//  ReportExportViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import Combine
import SwiftUI

/// The export screen's state: what is selected, and the file it produced.
@MainActor
final class ReportExportViewModel: ObservableObject {

    // MARK: - Types

    struct CourseOption: Identifiable, Equatable {
        let id: UUID
        let name: String
        let startDate: Date
        let endDate: Date
    }

    // MARK: - Properties

    /// Any change discards the made file, so a stale document is never shared.
    @Published var selection: ReportSelection {
        didSet { document = nil }
    }

    @Published private(set) var courses: [CourseOption] = []
    @Published private(set) var isWorking = false
    @Published private(set) var document: URL?

    private let database: any CourseStoring & DiaryStoring & BloodPressureStoring & ReportReading
    private let images: any ImageLoading
    private let errors: any ErrorReporting
    private let time: any TimeSource
    /// Read at build time, not on open: the profile may have changed since.
    private let profile: () -> UserProfile

    // MARK: - Init

    init(
        database: any CourseStoring & DiaryStoring & BloodPressureStoring & ReportReading,
        images: any ImageLoading,
        errors: any ErrorReporting,
        profile: @escaping () -> UserProfile,
        calendar: Calendar = .current,
        time: any TimeSource = SystemTime()
    ) {
        self.profile = profile
        let today = time.now
        self.time = time
        self.database = database
        self.images = images
        self.errors = errors

        // Last 30 days by default.
        let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        self.selection = ReportSelection(from: start, to: today)
    }

    // MARK: - Loading

    var canExport: Bool { !selection.sections.isEmpty && selection.from <= selection.to }

    func load() {
        courses = database.fetchAllCourses()
            .sorted { $0.startDate > $1.startDate }
            .map { CourseOption(id: $0.id, name: $0.name, startDate: $0.startDate, endDate: $0.endDate) }

        // All courses selected initially.
        if selection.courseIds.isEmpty {
            selection.courseIds = Set(courses.map(\.id))
        }
    }

    // MARK: - Selection

    func toggle(_ section: ReportSection) {
        if selection.sections.contains(section) {
            selection.sections.remove(section)
        } else {
            selection.sections.insert(section)
        }
    }

    func toggle(courseId: UUID) {
        if selection.courseIds.contains(courseId) {
            selection.courseIds.remove(courseId)
        } else {
            selection.courseIds.insert(courseId)
        }
    }

    // MARK: - Document

    func makeDocument() async {
        guard !isWorking, canExport else { return }

        isWorking = true
        defer { isWorking = false }

        do {
            // Read, photos and rendering all off the main actor.
            let data = try await database.reportData(for: selection, profile: profile(), now: time.now)
            let photos = selection.includesPhotos ? await photos(in: data) : [:]
            document = try await Self.renderDocument(data, photos: photos)
        } catch {
            errors.report(error)
        }
    }

    /// Rendering and writing the PDF is slow, so it runs detached, off the main actor.
    nonisolated private static func renderDocument(_ data: ReportData, photos: [UUID: UIImage]) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let rendered = ReportRenderer().render(data, photos: photos)
            return try ReportDocument.write(rendered, for: data)
        }.value
    }

    /// Decoded up front: photo loading is async, page drawing is synchronous.
    private func photos(in data: ReportData) async -> [UUID: UIImage] {
        var photos: [UUID: UIImage] = [:]

        for id in Set(data.diary.flatMap(\.photoIds)) {
            photos[id] = await images.image(for: id, targetPointSize: 220)
        }
        return photos
    }
}
