//
//  DIContainer.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Swinject
import SwiftUI

// @MainActor because DatabaseService works with SwiftData on the UI thread.
@MainActor
final class DIContainer {

    static let shared = DIContainer()

    let container: Container

    private init() {
        container = Container()
        registerDependencies()
    }

    private func registerDependencies() {

        // MARK: - Services (mostly singletons)

        // .container scope = singleton: there must be exactly one database instance
        // for the whole app.
        container.register(DatabaseServiceProtocol.self) { _ in
            DatabaseService.shared
        }.inObjectScope(.container)

        container.register(NotificationServiceProtocol.self) { _ in
            NotificationService()
        }.inObjectScope(.container)

        container.register(MediaPickerServiceProtocol.self) { _ in
            MediaPickerService()
        }.inObjectScope(.container)

        // MARK: - View models

        // .transient scope = a fresh instance is created every time (clean screen state).
        container.register(OnboardingViewModel.self) { _ in
            OnboardingViewModel()
        }.inObjectScope(.transient)

        // Dashboard needs notifService too: marking a dose as taken has to
        // reschedule pending notifications so a stale reminder doesn't linger.
        container.register(DashboardViewModel.self) { r in
            DashboardViewModel(
                dbService: r.resolve(DatabaseServiceProtocol.self)!,
                notificationService: r.resolve(NotificationServiceProtocol.self)!
            )
        }.inObjectScope(.transient)

        container.register(NewTreatmentViewModel.self) { r in
            NewTreatmentViewModel(
                dbService: r.resolve(DatabaseServiceProtocol.self)!,
                notificationService: r.resolve(NotificationServiceProtocol.self)!
            )
        }.inObjectScope(.transient)

        container.register(CoursesListViewModel.self) { r in
            CoursesListViewModel(
                dbService: r.resolve(DatabaseServiceProtocol.self)!,
                notificationService: r.resolve(NotificationServiceProtocol.self)!
            )
        }.inObjectScope(.transient)

        container.register(CourseDetailViewModel.self) { (r, course: TreatmentCourse) in
            CourseDetailViewModel(
                course: course,
                dbService: r.resolve(DatabaseServiceProtocol.self)!,
                notificationService: r.resolve(NotificationServiceProtocol.self)!
            )
        }.inObjectScope(.transient)

        container.register(StatisticsViewModel.self) { r in
            StatisticsViewModel(dbService: r.resolve(DatabaseServiceProtocol.self)!)
        }.inObjectScope(.transient)

        container.register(AddMedicationViewModel.self) { r in
            AddMedicationViewModel(mediaPickerService: r.resolve(MediaPickerServiceProtocol.self)!)
        }.inObjectScope(.transient)

        container.register(DiaryViewModel.self) { r in
            DiaryViewModel(dbService: r.resolve(DatabaseServiceProtocol.self)!)
        }.inObjectScope(.transient)

        container.register(DiaryCheckInViewModel.self) { r in
            DiaryCheckInViewModel(
                dbService: r.resolve(DatabaseServiceProtocol.self)!,
                mediaPickerService: r.resolve(MediaPickerServiceProtocol.self)!
            )
        }.inObjectScope(.transient)

        // Takes the database through the three protocols an export actually
        // reads, rather than the whole of DatabaseServiceProtocol: nothing here
        // writes, and the narrower type says so.
        container.register(ReportExportViewModel.self) { r in
            ReportExportViewModel(database: r.resolve(DatabaseServiceProtocol.self)!)
        }.inObjectScope(.transient)
    }

    // Generic resolve helpers that unwrap the optional Swinject returns.
    func resolve<T>(_ type: T.Type) -> T {
        guard let resolved = container.resolve(type) else {
            fatalError("DI Error: Failed to resolve dependency for \(type). Check the registration in DIContainer.")
        }
        return resolved
    }

    func resolve<T, Arg>(_ type: T.Type, argument: Arg) -> T {
        guard let resolved = container.resolve(type, argument: argument) else {
            fatalError("DI Error: Failed to resolve dependency for \(type) with argument.")
        }
        return resolved
    }
}
