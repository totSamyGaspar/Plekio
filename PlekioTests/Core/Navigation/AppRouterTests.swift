//
//  AppRouterTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 04.09.2026.
//

import Testing
import Foundation
@testable import Plekio
import SwiftUI

@MainActor
@Suite("AppRouter Tests")
struct AppRouterTests {

    // MARK: - Daily reminders

    @Test("The blood-pressure reminder opens the diary on the readings tab")
    func testBloodPressureReminderDeepLinksToTrends() {
        let router = AppRouter()

        router.open(.dailyReminder(.bloodPressure))

        #expect(router.selectedTab == .diary)
        #expect(router.pendingDeepLink == .dailyReminder(.bloodPressure))
        // So dismissing the entry form reveals the new reading, not the feed.
        #expect(router.pendingDiarySubTab == .moodTrends)
    }

    @Test("The diary reminder doesn't switch the sub-tab")
    func testDiaryReminderLeavesTheSubTabAlone() {
        let router = AppRouter()

        router.open(.dailyReminder(.diary))

        #expect(router.selectedTab == .diary)
        #expect(router.pendingDeepLink == .dailyReminder(.diary))
        #expect(router.pendingDiarySubTab == nil)
    }

    // MARK: - Dose reminders

    @Test("A dose reminder opens Today and carries the whole slot")
    func testDosePushCarriesItsSlot() {
        let router = AppRouter()
        let ids = [UUID(), UUID()]
        let slot = Date(timeIntervalSince1970: 1_780_000_000)

        router.open(.doseReminder(medicationIds: ids, slot: slot))

        #expect(router.selectedTab == .today)
        #expect(router.consumeDeepLink() == .doseReminder(medicationIds: ids, slot: slot))
        #expect(router.pendingDiarySubTab == nil)
    }

    // MARK: - Consuming

    @Test("A link is consumed once")
    func testDeepLinkIsConsumedOnce() {
        // Both .task and .onChange consume it for one tap; a second read must be nil.
        let router = AppRouter()
        router.open(.dailyReminder(.bloodPressure))

        #expect(router.consumeDeepLink() == .dailyReminder(.bloodPressure))
        #expect(router.consumeDeepLink() == nil)

        #expect(router.consumePendingDiarySubTab() == .moodTrends)
        #expect(router.consumePendingDiarySubTab() == nil)
    }

    @Test("Consuming without a link returns nothing")
    func testNothingToConsumeByDefault() {
        let router = AppRouter()

        #expect(router.consumeDeepLink() == nil)
        #expect(router.consumePendingDiarySubTab() == nil)
    }

    @Test("A new link replaces one not yet handled")
    func testALaterLinkReplacesAnUnconsumedOne() {
        let router = AppRouter()
        router.open(.dailyReminder(.diary))
        router.open(.doseReminder(medicationIds: [UUID()], slot: Date()))

        #expect(router.selectedTab == .today)
        if case .doseReminder = router.consumeDeepLink() {} else {
            Issue.record("expected the dose reminder to win")
        }
    }

    // MARK: - Sheets

    @Test("dismissSheet closes both the sheet and the full-screen cover")
    func testDismissClearsBothPresentations() {
        let router = AppRouter()
        router.present(.diaryCheckIn)
        router.presentFullScreen(.bloodPressureEntry)

        router.dismissSheet()

        #expect(router.activeSheet == nil)
        #expect(router.activeFullScreen == nil)
    }

    // MARK: - Navigation

    @Test("showCourse opens the course on the Courses tab over an empty stack")
    func testShowCourseOpensItsDetail() {
        let router = AppRouter()
        router.coursesPath.append(Route.courseDetail(courseId: UUID()))

        router.showCourse(id: UUID())

        #expect(router.selectedTab == .courses)
        #expect(router.coursesPath.count == 1)
    }
}
