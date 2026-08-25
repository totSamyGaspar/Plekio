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

        // .container scope = singleton. There must be only one database instance for the whole app.
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
        container.register((any OnboardingViewModelProtocol).self) { _ in
            OnboardingViewModel()
        }.inObjectScope(.transient)

        // Dashboard needs notifService too: marking a dose as taken has to
        // reschedule pending notifications so a stale reminder doesn't linger.
        container.register((any DashboardViewModelProtocol).self) { r in
            let dbService = r.resolve(DatabaseServiceProtocol.self)!
            let notifService = r.resolve(NotificationServiceProtocol.self)!
            return DashboardViewModel(dbService: dbService, notificationService: notifService)
        }.inObjectScope(.transient)

        container.register((any NewTreatmentViewModelProtocol).self) { r in
            let dbService = r.resolve(DatabaseServiceProtocol.self)!
            let notifService = r.resolve(NotificationServiceProtocol.self)!
            return NewTreatmentViewModel(dbService: dbService, notificationService: notifService)
        }.inObjectScope(.transient)

        container.register((any CoursesListViewModelProtocol).self) { r in
            let dbService = r.resolve(DatabaseServiceProtocol.self)!
            let notifService = r.resolve(NotificationServiceProtocol.self)!
            return CoursesListViewModel(dbService: dbService, notificationService: notifService)
        }.inObjectScope(.transient)

        container.register((any CourseDetailViewModelProtocol).self) { (r, course: TreatmentCourse) in
            let dbService = r.resolve(DatabaseServiceProtocol.self)!
            let notifService = r.resolve(NotificationServiceProtocol.self)!
            return CourseDetailViewModel(course: course, dbService: dbService, notificationService: notifService)
        }.inObjectScope(.transient)

        container.register((any StatisticsViewModelProtocol).self) { r in
            return StatisticsViewModel(dbService: r.resolve(DatabaseServiceProtocol.self)!)
        }.inObjectScope(.transient)

        // Note: CourseRowViewModelProtocol is intentionally not registered here —
        // CourseRowView constructs CourseRowViewModel(course:) directly in its
        // own init, bypassing the container, so a factory here would be dead code.

        container.register((any AddMedicationViewModelProtocol).self) { r in
            let mediaService = r.resolve(MediaPickerServiceProtocol.self)!
            return AddMedicationViewModel(mediaPickerService: mediaService)
        }.inObjectScope(.transient)

        container.register((any DiaryViewModelProtocol).self) { r in
            let dbService = r.resolve(DatabaseServiceProtocol.self)!
            return DiaryViewModel(dbService: dbService)
        }.inObjectScope(.transient)

        container.register((any DiaryCheckInViewModelProtocol).self) { r in
            let dbService = r.resolve(DatabaseServiceProtocol.self)!
            let mediaService = r.resolve(MediaPickerServiceProtocol.self)!
            return DiaryCheckInViewModel(dbService: dbService, mediaPickerService: mediaService)
        }.inObjectScope(.transient)
    }

    // Generic resolve helpers that unwrap the optional Swinject returns.
    func resolve<T>(_ type: T.Type) -> T {
        guard let resolved = container.resolve(type) else {
            fatalError("🚨 DI Error: Failed to resolve dependency for \(type). Check the registration in DIContainer.")
        }
        return resolved
    }

    func resolve<T, Arg>(_ type: T.Type, argument: Arg) -> T {
        guard let resolved = container.resolve(type, argument: argument) else {
            fatalError("🚨 DI Error: Failed to resolve dependency for \(type) with argument.")
        }
        return resolved
    }
}
