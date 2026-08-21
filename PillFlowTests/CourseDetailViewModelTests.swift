//
//  PillFlowTests.swift
//  PillFlowTests
//
//  Created by Edward Gasparian on 06.06.2026.
//

//import Testing
//import Foundation
//@testable import PillFlow
//
//@MainActor
//@Suite("CourseDetailViewModel Tests")
//struct CourseDetailViewModelTests {
//
//    @Test("Инициализация ViewModel присваивает правильные начальные значения")
//    func testInitialization() async throws {
//        // Arrange
//        let mockDB = MockDatabaseService()
//        let mockNotifications = MockNotificationService()
//        
//        let startDate = Date()
//        let endDate = Date().addingTimeInterval(86400 * 7) // +7 дней
//        
//        // Создаем фиктивный курс (свойства зависят от вашей модели)
//        let dummyCourse = TreatmentCourse(
//            name: "Антибиотики",
//            startDate: startDate,
//            endDate: endDate
//        )
//        
//        // Act
//        let vm = CourseDetailViewModel(course: dummyCourse, dbService: mockDB, notificationService: mockNotifications)
//        
//        // Assert
//        #expect(vm.courseName == "Антибиотики")
//        #expect(vm.startDate == startDate)
//        #expect(vm.endDate == endDate)
//        #expect(vm.medications.isEmpty)
//    }
//    
//
//}
