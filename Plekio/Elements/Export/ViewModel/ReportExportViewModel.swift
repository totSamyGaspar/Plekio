//
//  ReportExportViewModel.swift
//  Plekio
//

import Combine
import SwiftUI

/// The export screen's state: what is selected, and the file it produced.
@MainActor
final class ReportExportViewModel: ObservableObject {

    struct CourseOption: Identifiable, Equatable {
        let id: UUID
        let name: String
        let startDate: Date
        let endDate: Date
    }

    /// Every change throws away the file already made. Sharing a document that
    /// no longer matches the screen that produced it is the one mistake here
    /// nobody would catch — least of all the person receiving it.
    @Published var selection: ReportSelection {
        didSet { document = nil }
    }

    @Published private(set) var courses: [CourseOption] = []
    @Published private(set) var isWorking = false
    @Published private(set) var document: URL?

    private let database: any CourseStoring & DiaryStoring & BloodPressureStoring

    init(
        database: any CourseStoring & DiaryStoring & BloodPressureStoring,
        calendar: Calendar = .current,
        today: Date = Date()
    ) {
        self.database = database

        // A month back by default: long enough to be worth sending, short
        // enough that the first document is not a hundred pages.
        let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        self.selection = ReportSelection(from: start, to: today)
    }

    var canExport: Bool { !selection.sections.isEmpty && selection.from <= selection.to }

    func load() {
        courses = database.fetchAllCourses()
            .sorted { $0.startDate > $1.startDate }
            .map { CourseOption(id: $0.id, name: $0.name, startDate: $0.startDate, endDate: $0.endDate) }

        // Everything is on to begin with: the screen opens showing what a
        // document would contain, and the user removes rather than hunts.
        if selection.courseIds.isEmpty {
            selection.courseIds = Set(courses.map(\.id))
        }
    }

    // MARK: - Editing the selection

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

    // MARK: - Making the document

    func makeDocument() async {
        guard !isWorking, canExport else { return }

        isWorking = true
        defer { isWorking = false }

        let data = ReportBuilder(database: database).build(selection)
        let photos = selection.includesPhotos ? await photos(in: data) : [:]
        let rendered = ReportRenderer().render(data, photos: photos)

        do {
            document = try ReportDocument.write(rendered, for: data)
        } catch {
            AppErrorPresenter.shared.report(error)
        }
    }

    /// Decoded before drawing starts: reading a photo is asynchronous and
    /// drawing a page is not, so they cannot be interleaved.
    private func photos(in data: ReportData) async -> [UUID: UIImage] {
        var photos: [UUID: UIImage] = [:]

        for id in Set(data.diary.flatMap(\.photoIds)) {
            photos[id] = await ImageCache.shared.image(for: id, targetPointSize: 220)
        }
        return photos
    }
}
