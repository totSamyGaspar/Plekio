//
//  AppDependencies+ViewModels.swift
//  Plekio
//
//  The factory for screens' view models. A parent view calls one of these when
//  it creates a child screen:
//
//      DashboardView(viewModel: dependencies.makeDashboardViewModel())
//
//  The screens take their view model through an `@autoclosure` that feeds
//  `StateObject`, so the factory runs once per screen, not on every re-render.
//
//  Each view model gets the narrowest dependency it needs — a use case for
//  writes, the database protocol for reads — never the container itself.
//

import Foundation

extension AppDependencies {

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel()
    }

    // MARK: - Today

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(dbService: database, doseLogging: doseLogging)
    }

    func makeStatisticsViewModel() -> StatisticsViewModel {
        StatisticsViewModel(dbService: database)
    }

    // MARK: - Courses

    func makeCoursesListViewModel() -> CoursesListViewModel {
        CoursesListViewModel(dbService: database, courseEditing: courseEditing)
    }

    func makeCourseDetailViewModel(course: TreatmentCourse) -> CourseDetailViewModel {
        CourseDetailViewModel(course: course, courseEditing: courseEditing)
    }

    func makeNewTreatmentViewModel() -> NewTreatmentViewModel {
        NewTreatmentViewModel(courseEditing: courseEditing)
    }

    func makeAddMedicationViewModel() -> AddMedicationViewModel {
        AddMedicationViewModel(mediaPickerService: mediaPicker)
    }

    // MARK: - Diary

    func makeDiaryViewModel() -> DiaryViewModel {
        DiaryViewModel(dbService: database)
    }

    func makeDiaryCheckInViewModel() -> DiaryCheckInViewModel {
        DiaryCheckInViewModel(dbService: database, mediaPickerService: mediaPicker)
    }

    // MARK: - Settings

    func makeReportExportViewModel() -> ReportExportViewModel {
        ReportExportViewModel(database: database)
    }
}
