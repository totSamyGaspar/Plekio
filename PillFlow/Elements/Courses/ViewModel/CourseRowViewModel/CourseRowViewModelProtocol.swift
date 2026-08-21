//
//  CourseRowViewModelProtocol.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.05.2026.
//

import SwiftUI

protocol CourseRowViewModelProtocol {
    var title: String { get }
    var medicationsCountText: String { get }
    var dateRangeText: String { get }
    var totalDays: Int { get }
    var currentDayNumber: Int { get }
    var daysProgress: Double { get }
}
