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
        OnboardingViewModel(settings: settings)
    }

    // MARK: - Today

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(dbService: database, doseLogging: doseLogging, errors: errorPresenter, time: time, undoCenter: doseUndo)
    }

    func makeStatisticsViewModel() -> StatisticsViewModel {
        StatisticsViewModel(courses: courseRepository, doses: database, errors: errorPresenter, time: time)
    }

    // MARK: - Courses

    func makeCoursesListViewModel() -> CoursesListViewModel {
        CoursesListViewModel(courses: courseRepository, courseEditing: courseEditing, errors: errorPresenter, time: time)
    }

    func makeCourseDetailViewModel(course: CourseSnapshot) -> CourseDetailViewModel {
        CourseDetailViewModel(course: course, courses: courseRepository, courseEditing: courseEditing, errors: errorPresenter)
    }

    func makeNewTreatmentViewModel() -> NewTreatmentViewModel {
        NewTreatmentViewModel(courseEditing: courseEditing, errors: errorPresenter)
    }

    func makeAddMedicationViewModel() -> AddMedicationViewModel {
        AddMedicationViewModel(mediaPickerService: mediaPicker, photos: photoCache)
    }

    // MARK: - Diary

    func makeDiaryViewModel() -> DiaryViewModel {
        DiaryViewModel(diary: diaryRepository, errors: errorPresenter, time: time)
    }

    func makeDiaryCheckInViewModel() -> DiaryCheckInViewModel {
        DiaryCheckInViewModel(diary: diaryRepository, mediaPickerService: mediaPicker, photos: photoCache, errors: errorPresenter)
    }

    // MARK: - Settings

    func makeReportExportViewModel() -> ReportExportViewModel {
        ReportExportViewModel(database: database, images: photoCache, errors: errorPresenter, time: time)
    }
}
