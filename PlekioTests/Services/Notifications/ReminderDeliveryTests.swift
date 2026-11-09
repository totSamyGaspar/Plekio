//
//  ReminderDeliveryTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 09.11.2026.
//

import Testing
import UserNotifications
@testable import Plekio

@Suite("ReminderDelivery")
struct ReminderDeliveryTests {

    @Test("Not asked yet is not off: the prompt is still to come")
    func notDetermined() {
        #expect(ReminderDelivery(authorization: .notDetermined, showsAnywhere: false) == .notAsked)
    }

    @Test("Denied is off")
    func denied() {
        #expect(ReminderDelivery(authorization: .denied, showsAnywhere: true) == .off)
    }

    @Test("Allowed reaches the person only if it shows somewhere")
    func allowed() {
        #expect(ReminderDelivery(authorization: .authorized, showsAnywhere: true) == .on)
        #expect(ReminderDelivery(authorization: .authorized, showsAnywhere: false) == .off)
        #expect(ReminderDelivery(authorization: .provisional, showsAnywhere: true) == .on)
    }
}
