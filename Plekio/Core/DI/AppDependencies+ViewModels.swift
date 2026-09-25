//
//  AppDependencies+ViewModels.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

extension AppDependencies {

    // MARK: - Onboarding

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(settings: settings)
    }

    // MARK: - Today

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(dbService: database, doseLogging: doseLogging, errors: errorPresenter, time: time, undoCenter: doseUndo)
    }

    func makeStatisticsViewModel() -> StatisticsViewModel {
        StatisticsViewModel(courses: courseRepository, doses: database, errors: errorPresenter, changes: database.changes, time: time)
    }

    // MARK: - Courses

    func makeCoursesListViewModel() -> CoursesListViewModel {
        CoursesListViewModel(courses: courseRepository, courseEditing: courseEditing, errors: errorPresenter, changes: database.changes, time: time)
    }

    func makeCourseDetailViewModel(course: CourseSnapshot) -> CourseDetailViewModel {
        CourseDetailViewModel(course: course, courses: courseRepository, courseEditing: courseEditing, errors: errorPresenter)
    }

    func makeNewTreatmentViewModel() -> NewTreatmentViewModel {
        NewTreatmentViewModel(courseEditing: courseEditing, errors: errorPresenter)
    }

    func makeAddMedicationViewModel() -> AddMedicationViewModel {
        AddMedicationViewModel(photos: photoCache)
    }

    // MARK: - Diary

    func makeDiaryViewModel() -> DiaryViewModel {
        DiaryViewModel(diary: diaryRepository, errors: errorPresenter, changes: database.changes, time: time)
    }

    func makeDiaryCheckInViewModel() -> DiaryCheckInViewModel {
        DiaryCheckInViewModel(diary: diaryRepository, photos: photoCache, errors: errorPresenter)
    }

    // MARK: - Settings

    func makeReportExportViewModel() -> ReportExportViewModel {
        ReportExportViewModel(
            database: database,
            images: photoCache,
            errors: errorPresenter,
            profile: { [settings] in settings.userProfile },
            time: time
        )
    }

    func makeProfileAvatarEditor() -> ProfileAvatarEditor {
        ProfileAvatarEditor(photos: photoCache)
    }
}
