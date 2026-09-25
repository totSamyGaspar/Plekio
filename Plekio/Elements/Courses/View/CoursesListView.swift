//
//  CoursesListView.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI

struct CoursesListView<VM: CoursesListViewModelProtocol>: View {
    @StateObject private var viewModel: VM
    @EnvironmentObject private var router: AppRouter
    
    @State private var selectedSegment = 0
    @State private var showingDeleteAlert = false
    @State private var courseToDelete: CourseSnapshot?
    @State private var courseToRepeat: CourseSnapshot?
    
    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                Picker("Course Filter", selection: $selectedSegment) {
                    Text("Active").tag(0)
                    Text("History").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color.appBackground)
                
                let currentList = selectedSegment == 0 ? viewModel.activeCourses : viewModel.historyCourses
                
                List {
                    if currentList.isEmpty {
                        EmptyStateView(
                            icon: selectedSegment == 0 ? "pills.fill" : "clock.arrow.circlepath",
                            title: selectedSegment == 0 ? "No active courses" : "History is empty",
                            verticalPadding: 80
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(currentList) { course in
                            Group {
                                // A finished course has nothing left to edit, so the
                                // history card is inert: the only thing it offers is
                                // starting the same treatment over.
                                if selectedSegment == 1 {
                                    CourseRowView(
                                        course: course,
                                        isHistory: true,
                                        canRepeat: !viewModel.hasActiveRepeat(of: course)
                                    ) {
                                        courseToRepeat = course
                                    }
                                } else {
                                    NavigationLink(value: Route.courseDetail(courseId: course.id)) {
                                        CourseRowView(course: course, isHistory: false)
                                    }
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    courseToDelete = course
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .alert("Delete Course?", isPresented: $showingDeleteAlert, presenting: courseToDelete) { course in
                    Button("Delete", role: .destructive) {
                        viewModel.deleteCourse(course)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { course in
                    Text("Are you sure you want to delete '\(course.name)'? This action cannot be undone.")
                }
                .sheet(item: $courseToRepeat) { course in
                    RepeatCourseSheet(course: course) { startDate, endDate in
                        viewModel.repeatCourse(course, startDate: startDate, endDate: endDate)
                        // The copy is active by definition, so the user is shown
                        // where it landed instead of an unchanged History list.
                        selectedSegment = 0
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("My Courses")
                    .scaledFont(size: 30, relativeTo: .title, weight: .heavy, design: .serif)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            
            Spacer(minLength: 0)
            
            Button(action: { router.present(.newTreatment) }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.accentPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.textPrimary.opacity(0.04)))
                    .overlay(Circle().stroke(Color.textPrimary.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Course")
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
}

#Preview {
    NavigationStack {
        CoursesListView(viewModel: AppDependencies.preview.makeCoursesListViewModel())
            .appTheme()
    }
    .environment(AppDependencies.preview)
}
