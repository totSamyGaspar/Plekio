//
//  Binding+TimeOfDay.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

extension Binding where Value == Int {

    /// Minutes past midnight as today's date, for an hour-and-minute DatePicker.
    var timeOfDay: Binding<Date> {
        Binding<Date>(
            get: {
                let (hour, minute) = MinuteOfDay.hourAndMinute(wrappedValue)
                return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
            },
            set: { wrappedValue = MinuteOfDay.of($0, calendar: .current) }
        )
    }
}
