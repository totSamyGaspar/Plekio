//
//  NewTreatmentViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Combine
import SwiftUI

@MainActor
final class NewTreatmentViewModel: NewTreatmentViewModelProtocol {
    @Published var courseName: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @Published var medications: [MedicationDraft] = []
    
    private let dbService: DatabaseServiceProtocol
    private let notificationService: NotificationServiceProtocol
    
    init(dbService: DatabaseServiceProtocol, notificationService: NotificationServiceProtocol) {
        self.dbService = dbService
        self.notificationService = notificationService
    }
    
    var isSaveEnabled: Bool {
        !courseName.trimmingCharacters(in: .whitespaces).isEmpty && !medications.isEmpty
    }
    
    func addMedication(_ draft: MedicationDraft) { medications.append(draft) }
    func deleteMedication(at offsets: IndexSet) { medications.remove(atOffsets: offsets) }
    
    /// Returns `false` if the save failed — the view then keeps the screen open
    /// instead of losing what was typed.
    @discardableResult
    func saveCourse() -> Bool {
        guard AppErrorPresenter.shared.run({
            try dbService.saveCourse(name: courseName, startDate: startDate, endDate: endDate, drafts: medications)
        }) else { return false }

        notificationService.rescheduleAll(using: dbService)
        return true
    }
}
