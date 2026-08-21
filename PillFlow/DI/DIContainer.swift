//
//  DIContainer.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Swinject
import SwiftUI

// Добавляем @MainActor, так как наш DatabaseService работает со SwiftData (UI-поток)
@MainActor
final class DIContainer {
    
    static let shared = DIContainer()
    
    let container: Container
    
    private init() {
        container = Container()
        registerDependencies()
    }
    
    // В этом методе мы регистрируем все наши протоколы
    private func registerDependencies() {
        
        // =================================================================
        // 1. СЕРВИСЫ (Обычно Синглтоны)
        // =================================================================
        
        // .container означает, что это Singleton. База данных должна быть одна на всё приложение.
        container.register(DatabaseServiceProtocol.self) { _ in
            DatabaseService.shared
        }.inObjectScope(.container)
        
        container.register(NotificationServiceProtocol.self) { _ in
            NotificationService()
        }.inObjectScope(.container)
        
        // ИСПРАВЛЕНО: Добавлена регистрация сервиса камеры и галереи
        container.register(MediaPickerServiceProtocol.self) { _ in
            MediaPickerService()
        }.inObjectScope(.container)
        
        // =================================================================
        // 2. VIEW MODELS
        // =================================================================
        
        // .transient означает, что каждый раз будет создаваться новый экземпляр (чистый экран).
        container.register((any OnboardingViewModelProtocol).self) { _ in
            OnboardingViewModel()
        }.inObjectScope(.transient)
        
        // Регистрируем Dashboard, прося контейнер (буква 'r') выдать нам сервис БД
        container.register((any DashboardViewModelProtocol).self) { r in
            let dbService = r.resolve(DatabaseServiceProtocol.self)!
            return DashboardViewModel(dbService: dbService)
        }.inObjectScope(.transient)
        
        // Аналогично регистрируем экран создания курса
        container.register((any NewTreatmentViewModelProtocol).self) { r in
            let dbService = r.resolve(DatabaseServiceProtocol.self)!
            let notifService = r.resolve(NotificationServiceProtocol.self)! // Достаем сервис пушей
            return NewTreatmentViewModel(dbService: dbService, notificationService: notifService) // Передаем его
        }.inObjectScope(.transient)
        
        container.register((any CoursesListViewModelProtocol).self) { r in
            let dbService = r.resolve(DatabaseServiceProtocol.self)!
            let notifService = r.resolve(NotificationServiceProtocol.self)! // Достаем сервис
            return CoursesListViewModel(dbService: dbService, notificationService: notifService) // Передаем
        }.inObjectScope(.transient)
        
        container.register((any CourseDetailViewModelProtocol).self) { (r, course: TreatmentCourse) in
            let dbService = r.resolve(DatabaseServiceProtocol.self)!
            let notifService = r.resolve(NotificationServiceProtocol.self)!
            return CourseDetailViewModel(course: course, dbService: dbService, notificationService: notifService)
        }.inObjectScope(.transient)
        
        container.register((any StatisticsViewModelProtocol).self) { r in
            return StatisticsViewModel(dbService: r.resolve(DatabaseServiceProtocol.self)!)
        }.inObjectScope(.transient)
        
        container.register((any CourseRowViewModelProtocol).self) { (resolver, course: TreatmentCourse) in
            return CourseRowViewModel(course: course)
        }.inObjectScope(.transient)
        
        // ИСПРАВЛЕНО: Удален дубликат фабрики. Оставлена одна чистая регистрация.
        container.register((any AddMedicationViewModelProtocol).self) { r in
            let mediaService = r.resolve(MediaPickerServiceProtocol.self)!
            return AddMedicationViewModel(mediaPickerService: mediaService)
        }.inObjectScope(.transient)
    }
    
    // Универсальный метод для извлечения зависимостей без опционалов
    func resolve<T>(_ type: T.Type) -> T {
        guard let resolved = container.resolve(type) else {
            fatalError("🚨 DI Error: Не удалось разрешить зависимость для \(type). Проверь регистрацию в DIContainer.")
        }
        return resolved
    }
    
    func resolve<T, Arg>(_ type: T.Type, argument: Arg) -> T {
        guard let resolved = container.resolve(type, argument: argument) else {
            fatalError("🚨 DI Error: Не удалось разрешить зависимость для \(type) с аргументом.")
        }
        return resolved
    }
}
