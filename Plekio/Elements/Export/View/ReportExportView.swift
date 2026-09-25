//
//  ReportExportView.swift
//  Plekio
//

import SwiftUI

/// Choosing what goes into a document, and handing the result to the share
/// sheet.
struct ReportExportView: View {

    @StateObject private var viewModel: ReportExportViewModel

    init(viewModel: @autoclosure @escaping () -> ReportExportViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            Form {
                period
                content
                if viewModel.selection.includes(.medications) { courses }
                action
            }
            .scrollContentBackground(.hidden)
            .tint(.accentPrimary)
        }
        .navigationTitle("Export")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
    }

    // MARK: - Period

    private var period: some View {
        Section(header: Text("Period").foregroundColor(.textSecondary)) {
            DatePicker("From", selection: $viewModel.selection.from, in: ...viewModel.selection.to, displayedComponents: .date)
            DatePicker("To", selection: $viewModel.selection.to, in: viewModel.selection.from...Date(), displayedComponents: .date)
        }
        .foregroundColor(.textPrimary)
        .appColorScheme()
        .listRowBackground(Color.appSurface)
    }

    // MARK: - What goes in

    private var content: some View {
        Section(header: Text("Include").foregroundColor(.textSecondary)) {
            ForEach(ReportSection.allCases) { section in
                Toggle(isOn: binding(for: section)) {
                    Text(section.title).foregroundColor(.textPrimary)
                }
            }

            if viewModel.selection.includes(.diary) {
                Toggle(isOn: $viewModel.selection.includesPhotos) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Diary photos").foregroundColor(.textPrimary)
                        Text("Makes the file much larger")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
        .listRowBackground(Color.appSurface)
    }

    private func binding(for section: ReportSection) -> Binding<Bool> {
        Binding(
            get: { viewModel.selection.includes(section) },
            set: { _ in viewModel.toggle(section) }
        )
    }

    // MARK: - Courses

    private var courses: some View {
        Section(header: Text("Medications").foregroundColor(.textSecondary)) {
            if viewModel.courses.isEmpty {
                Text("No courses yet").foregroundColor(.textSecondary)
            }

            ForEach(viewModel.courses) { course in
                Button { viewModel.toggle(courseId: course.id) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(course.name).foregroundColor(.textPrimary)
                            Text(range(course))
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        Image(systemName: viewModel.selection.courseIds.contains(course.id)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.selection.courseIds.contains(course.id)
                                             ? .accentPrimary : .textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listRowBackground(Color.appSurface)
    }

    private func range(_ course: ReportExportViewModel.CourseOption) -> String {
        let day = Date.FormatStyle.dateTime.day().month(.abbreviated).year()
        return "\(course.startDate.formatted(day)) — \(course.endDate.formatted(day))"
    }

    // MARK: - Action

    /// Create first, share second. `ShareLink` needs the file in hand, and a
    /// single button that did both would have nothing to show while the
    /// document was still being drawn.
    private var action: some View {
        Section {
            if let document = viewModel.document {
                ShareLink(item: document) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .foregroundColor(.accentPrimary)
                        .frame(maxWidth: .infinity)
                }
            } else {
                Button {
                    Task { await viewModel.makeDocument() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isWorking {
                            ProgressView().tint(.accentPrimary)
                        } else {
                            Text("Create document").foregroundColor(.accentPrimary)
                        }
                        Spacer()
                    }
                }
                .disabled(!viewModel.canExport || viewModel.isWorking)
            }
        }
        .listRowBackground(Color.appSurface)
    }
}

extension ReportExportView {

    init() {
        self.init(viewModel: DIContainer.shared.resolve(ReportExportViewModel.self))
    }
}
