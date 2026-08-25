//
//  CoursesListView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI

struct CoursesListView<VM: CoursesListViewModelProtocol>: View {
    @StateObject private var viewModel: VM
    @EnvironmentObject private var router: AppRouter
    
    @State private var selectedSegment = 0
    @State private var showingDeleteAlert = false
    @State private var courseToDelete: TreatmentCourse?
    
    init(viewModel: @autoclosure @escaping () -> VM) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                Picker("Course Filter", selection: $selectedSegment) {
                    Text("Active").tag(0)
                    Text("History").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color.bgDark)
                
                let currentList = selectedSegment == 0 ? viewModel.activeCourses : viewModel.historyCourses
                
                List {
                    if currentList.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(currentList) { course in
                            NavigationLink(value: Route.courseDetail(course)) {
                                CourseRowView(course: course,
                                              isHistory: selectedSegment == 1)
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
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("My Courses")
                    .font(.system(size: 30, weight: .heavy, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
            
            Button(action: { router.present(.newTreatment) }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.neonMint)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.04)))
                    .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Empty state
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 100)
            Image(systemName: selectedSegment == 0 ? "pills.fill" : "clock.arrow.circlepath")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.2))
            Text(selectedSegment == 0 ? "No active courses" : "History is empty")
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

extension CoursesListView where VM == CoursesListViewModel {
    init() {
        self.init(viewModel: DIContainer.shared.resolve((any CoursesListViewModelProtocol).self) as! VM)
    }
}

#Preview {
    NavigationStack {
        CoursesListView()
            .preferredColorScheme(.dark)
    }
}
