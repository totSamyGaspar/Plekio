//
//  NotificationService.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

//import Foundation
//import UserNotifications
//
//final class NotificationService: NotificationServiceProtocol {
//    
//    private func registerNotificationCategories() {
//        let center = UNUserNotificationCenter.current()
//        
//        let takeAction = UNNotificationAction(identifier: "ACTION_TAKE", title: "Take Now", options: .foreground)
//        let snoozeAction = UNNotificationAction(identifier: "ACTION_SNOOZE", title: "Snooze 5m", options: [])
//        let skipAction = UNNotificationAction(identifier: "ACTION_SKIP", title: "Skip", options: .destructive)
//        
//        let category = UNNotificationCategory(
//            identifier: "PILL_REMINDER_CATEGORY",
//            actions: [takeAction, snoozeAction, skipAction],
//            intentIdentifiers: [],
//            options: .customDismissAction
//        )
//        
//        center.setNotificationCategories([category])
//    }
//    
//    func requestPermission() {
//        let center = UNUserNotificationCenter.current()
//        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
//            if granted {
//                print("✅ Уведомления разрешены пользователем")
//                self.registerNotificationCategories()
//            } else if let error = error {
//                print("🚨 Ошибка разрешений: \(error.localizedDescription)")
//            }
//        }
//    }
//    
//    func scheduleNotifications(activeCourses: [TreatmentCourse]) {
//        let center = UNUserNotificationCenter.current()
//        let calendar = Calendar.current
//        let today = calendar.startOfDay(for: Date())
//        let maxDate = calendar.date(byAdding: .day, value: 2, to: today) ?? today
//        
//        // СЛОВАРЬ ДЛЯ ГРУППИРОВКИ: [Точное время : [(Название курса, Препарат)]]
//        var scheduleMap: [Date: [(String, MedicationItem)]] = [:]
//        
//        // 1. Собираем все препараты со всех курсов и вычисляем их время
//        for course in activeCourses {
//            let startDay = calendar.startOfDay(for: course.startDate)
//            let endDay = calendar.startOfDay(for: course.endDate)
//            
//            for med in course.medications {
//                var currentDate = startDay
//                while currentDate <= endDay {
//                    if currentDate >= today && currentDate <= maxDate {
//                        for time in med.timesOfDay {
//                            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
//                            if let triggerDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: currentDate), triggerDate > Date() {
//                                
//                                // Складываем в массив по ключу точного времени
//                                scheduleMap[triggerDate, default: []].append((course.name, med))
//                            }
//                        }
//                    }
//                    if currentDate > maxDate { break }
//                    currentDate = calendar.date(byAdding: .day, value: med.frequencyDays, to: currentDate) ?? endDay.addingTimeInterval(1)
//                }
//            }
//        }
//        
//        // 2. Создаем по одному пушу на каждое уникальное время
//        var scheduledCount = 0
//        for (triggerDate, medsAtTime) in scheduleMap {
//            guard scheduledCount < 60 else { break } // Лимит iOS
//            
//            let content = UNMutableNotificationContent()
//            
//            // Склеиваем названия: "Омега-3, Витамин Д"
//            let medicationNames = medsAtTime.map { $0.1.name }.joined(separator: ", ")
//            // Собираем массив ID
//            let medicationIds = medsAtTime.map { $0.1.id.uuidString }
//            
//            content.title = "💊 Время приема"
//            content.body = "Пора принять: \(medicationNames)"
//            content.sound = .default
//            content.categoryIdentifier = "PILL_REMINDER_CATEGORY"
//            
//            // ТЕПЕРЬ ПЕРЕДАЕМ МАССИВ ID
//            content.userInfo = [
//                "medicationIds": medicationIds,
//                "time": triggerDate.timeIntervalSince1970
//            ]
//            
//            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
//            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
//            
//            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
//            center.add(request) { error in
//                if let error = error { print("🚨 Ошибка: \(error)") }
//            }
//            scheduledCount += 1
//        }
//        print("🔔 Сгруппировано и запланировано пушей: \(scheduledCount)")
//    }
//    
////    func scheduleSnooze(for pillName: String, dosage: String, medicationId: UUID, courseName: String) {
////        let center = UNUserNotificationCenter.current()
////        
////        let content = UNMutableNotificationContent()
////        content.title = "Напоминание: \(pillName)"
////        content.body = "Вы откладывали прием. Пора принять \(dosage)."
////        content.sound = .default
////        content.categoryIdentifier = "PILL_REMINDER_CATEGORY" // Чтобы у повторного пуша тоже были кнопки!
////        
////        // Передаем те же данные, чтобы Deep Link сработал и на повторном пуше
////        let triggerDate = Date().addingTimeInterval(5 * 60) // Текущее время + 5 минут
////        content.userInfo = [
////            "medicationId": medicationId.uuidString,
////            "time": triggerDate.timeIntervalSince1970
////        ]
////        
////        // Используем TimeInterval триггер вместо Calendar
////        // 300 секунд = 5 минут. Для тестов можешь поставить 10-15 секунд.
////        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)
////        
////        let request = UNNotificationRequest(
////            identifier: "SNOOZE_\(medicationId.uuidString)",
////            content: content,
////            trigger: trigger
////        )
////        
////        center.add(request) { error in
////            if let error = error { print("🚨 Ошибка планирования Snooze: \(error)") }
////            else { print("⏰ Запланирован повторный пуш через 5 минут") }
////        }
////    }
// 
//    func scheduleSnooze(for medicationIds: [String], combinedNames: String) {
//        let center = UNUserNotificationCenter.current()
//        let content = UNMutableNotificationContent()
//        
//        content.title = "Напоминание (Snooze)"
//        content.body = "Вы откладывали: \(combinedNames)"
//        content.sound = .default
//        content.categoryIdentifier = "PILL_REMINDER_CATEGORY"
//        
//        let triggerDate = Date().addingTimeInterval(5 * 60)
//        content.userInfo = [
//            "medicationIds": medicationIds, // Передаем массив!
//            "time": triggerDate.timeIntervalSince1970
//        ]
//        
//        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)
//        // Для группового снуза используем склеенные ID в качестве уникального идентификатора
//        let uniqueIdentifier = "SNOOZE_\(medicationIds.joined(separator: "_"))"
//        
//        let request = UNNotificationRequest(identifier: uniqueIdentifier, content: content, trigger: trigger)
//        center.add(request) { error in
//            if let error = error { print("🚨 Ошибка Snooze: \(error)") }
//        }
//    }
////    func cancelNotifications(for medicationId: UUID) {
////        let center = UNUserNotificationCenter.current()
////        
////        // Асинхронно запрашиваем у iOS список всех запланированных пушей нашего приложения
////        center.getPendingNotificationRequests { requests in
////            // Фильтруем только те, где спрятанный ID совпадает с удаляемой таблеткой
////            
////            
////            //// если юзер не отвели то отметить как пропузщенное NOTIFICATION!!!!!
////            
////            let identifiersToRemove = requests.compactMap { request -> String? in
////                if let reqMedId = request.content.userInfo["medicationId"] as? String,
////                   reqMedId == medicationId.uuidString {
////                    return request.identifier
////                }
////                return nil
////            }
////            
////            // Если нашли такие — просим систему их удалить
////            if !identifiersToRemove.isEmpty {
////                center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
////                print("🗑 Отменено \(identifiersToRemove.count) пуш-уведомлений для препарата")
////            }
////        }
////    }
//    
//    func cancelNotifications(for medicationId: UUID) {
//        let center = UNUserNotificationCenter.current()
//        center.getDeliveredNotifications { notifications in
//            let deliveredToRemove = notifications.compactMap { notif -> String? in
//                if let reqMedId = notif.request.content.userInfo["medicationId"] as? String,
//                   reqMedId == medicationId.uuidString {
//                    return notif.request.identifier
//                }
//                return nil
//            }
//            if !deliveredToRemove.isEmpty {
//                center.removeDeliveredNotifications(withIdentifiers: deliveredToRemove)
//                print("🧹 Уведомление убрано с экрана блокировки")
//            }
//        }
//
//        center.removePendingNotificationRequests(withIdentifiers: ["SNOOZE_\(medicationId.uuidString)"])
//        print("🗑 Таймер Snooze отменен")
//    }
//}

//
//  NotificationService.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import UserNotifications

final class NotificationService: NotificationServiceProtocol {
    
    private func registerNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        
        let takeAction = UNNotificationAction(identifier: "ACTION_TAKE", title: "Take Now", options: .foreground)
        let snoozeAction = UNNotificationAction(identifier: "ACTION_SNOOZE", title: "Snooze 5m", options: [])
        let skipAction = UNNotificationAction(identifier: "ACTION_SKIP", title: "Skip", options: .destructive)
        
        let category = UNNotificationCategory(
            identifier: "PILL_REMINDER_CATEGORY",
            actions: [takeAction, snoozeAction, skipAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        center.setNotificationCategories([category])
    }
    
    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Уведомления разрешены пользователем")
                self.registerNotificationCategories()
            } else if let error = error {
                print("🚨 Ошибка разрешений: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotifications(activeCourses: [TreatmentCourse]) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let maxDate = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        
        // СЛОВАРЬ ДЛЯ ГРУППИРОВКИ: [Точное время : [(Название курса, Препарат)]]
        var scheduleMap: [Date: [(String, MedicationItem)]] = [:]
        
        // 1. Собираем все препараты со всех курсов и вычисляем их время
        for course in activeCourses {
            let startDay = calendar.startOfDay(for: course.startDate)
            let endDay = calendar.startOfDay(for: course.endDate)
            
            for med in course.medications {
                var currentDate = startDay
                while currentDate <= endDay {
                    if currentDate >= today && currentDate <= maxDate {
                        for time in med.timesOfDay {
                            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                            if let triggerDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: currentDate), triggerDate > Date() {
                                
                                // Складываем в массив по ключу точного времени
                                scheduleMap[triggerDate, default: []].append((course.name, med))
                            }
                        }
                    }
                    if currentDate > maxDate { break }
                    currentDate = calendar.date(byAdding: .day, value: med.frequencyDays, to: currentDate) ?? endDay.addingTimeInterval(1)
                }
            }
        }
        
        // 2. Создаем по одному пушу на каждое уникальное время
        var scheduledCount = 0
        for (triggerDate, medsAtTime) in scheduleMap {
            guard scheduledCount < 60 else { break } // Лимит iOS
            
            let content = UNMutableNotificationContent()
            
            // Склеиваем названия: "Омега-3, Витамин Д"
            let medicationNames = medsAtTime.map { $0.1.name }.joined(separator: ", ")
            // Собираем массив ID
            let medicationIds = medsAtTime.map { $0.1.id.uuidString }
            
            content.title = "💊 Время приема"
            content.body = "Пора принять: \(medicationNames)"
            content.sound = .default
            content.categoryIdentifier = "PILL_REMINDER_CATEGORY"
            
            // ПЕРЕДАЕМ МАССИВ ID
            content.userInfo = [
                "medicationIds": medicationIds,
                "time": triggerDate.timeIntervalSince1970
            ]
            
            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            center.add(request) { error in
                if let error = error { print("🚨 Ошибка: \(error)") }
            }
            scheduledCount += 1
        }
        print("🔔 Сгруппировано и запланировано пушей: \(scheduledCount)")
    }
    
    func scheduleSnooze(for medicationIds: [String], combinedNames: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        
        content.title = "Напоминание (Snooze)"
        content.body = "Вы откладывали: \(combinedNames)"
        content.sound = .default
        content.categoryIdentifier = "PILL_REMINDER_CATEGORY"
        
        let triggerDate = Date().addingTimeInterval(5 * 60) // 5 минут
        content.userInfo = [
            "medicationIds": medicationIds, // Передаем массив!
            "time": triggerDate.timeIntervalSince1970
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)
        // Для группового снуза используем склеенные ID в качестве уникального идентификатора
        let uniqueIdentifier = "SNOOZE_\(medicationIds.joined(separator: "_"))"
        
        let request = UNNotificationRequest(identifier: uniqueIdentifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error { print("🚨 Ошибка Snooze: \(error)") }
        }
    }
    
    func cancelNotifications(for medicationId: UUID) {
        let center = UNUserNotificationCenter.current()
        let targetIdString = medicationId.uuidString
        
        // 1. Убираем уже доставленные пуши (с экрана блокировки)
        center.getDeliveredNotifications { notifications in
            let deliveredToRemove = notifications.compactMap { notif -> String? in
                if let reqMedIds = notif.request.content.userInfo["medicationIds"] as? [String],
                   reqMedIds.contains(targetIdString) {
                    return notif.request.identifier
                }
                return nil
            }
            if !deliveredToRemove.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: deliveredToRemove)
                print("🧹 Уведомления убраны с экрана блокировки: \(deliveredToRemove.count) шт.")
            }
        }
        
        // 2. Отменяем будущие (ожидающие) пуши для этой таблетки
        center.getPendingNotificationRequests { requests in
            let pendingToRemove = requests.compactMap { request -> String? in
                if let reqMedIds = request.content.userInfo["medicationIds"] as? [String],
                   reqMedIds.contains(targetIdString) {
                    return request.identifier
                }
                return nil
            }
            if !pendingToRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: pendingToRemove)
                print("🗑 Будущие пуши отменены: \(pendingToRemove.count) шт.")
            }
        }
        
        center.removePendingNotificationRequests(withIdentifiers: ["SNOOZE_\(targetIdString)"])
    }
}
