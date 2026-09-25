//
//  AppRouterTests.swift
//  PlekioTests
//
//  Tests for where a tapped notification takes the user. The router is the one
//  piece of that journey with no UIKit or notification centre in it, so it is
//  the piece that can be checked without a device.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("AppRouter Tests")
struct AppRouterTests {

    // MARK: - Daily reminders

    @Test("напоминание о давлении ведёт в дневник, на вкладку с показаниями")
    func testBloodPressureReminderDeepLinksToTrends() {
        let router = AppRouter()

        router.open(.dailyReminder(.bloodPressure))

        #expect(router.selectedTab == .diary)
        #expect(router.pendingDeepLink == .dailyReminder(.bloodPressure))
        // Behind the entry form: dismissing it should leave the new measurement
        // on screen, not the journal feed.
        #expect(router.pendingDiarySubTab == .moodTrends)
    }

    @Test("напоминание дневника не переключает подвкладку")
    func testDiaryReminderLeavesTheSubTabAlone() {
        let router = AppRouter()

        router.open(.dailyReminder(.diary))

        #expect(router.selectedTab == .diary)
        #expect(router.pendingDeepLink == .dailyReminder(.diary))
        // The check-in is not about any one sub-tab, so the diary opens wherever
        // the user left it.
        #expect(router.pendingDiarySubTab == nil)
    }

    // MARK: - Dose reminders

    @Test("пуш о приёме ведёт на сегодняшний экран и переносит слот целиком")
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

    @Test("ссылка забирается один раз")
    func testDeepLinkIsConsumedOnce() {
        // Consumed rather than read: the link is presented from a .task and an
        // .onChange, and both run for the same tap. A link that survived being
        // read would present the form twice.
        let router = AppRouter()
        router.open(.dailyReminder(.bloodPressure))

        #expect(router.consumeDeepLink() == .dailyReminder(.bloodPressure))
        #expect(router.consumeDeepLink() == nil)

        #expect(router.consumePendingDiarySubTab() == .moodTrends)
        #expect(router.consumePendingDiarySubTab() == nil)
    }

    @Test("без ссылки потребление ничего не возвращает")
    func testNothingToConsumeByDefault() {
        let router = AppRouter()

        #expect(router.consumeDeepLink() == nil)
        #expect(router.consumePendingDiarySubTab() == nil)
    }

    @Test("новая ссылка заменяет ещё не обработанную")
    func testALaterLinkReplacesAnUnconsumedOne() {
        // Two taps before the tab bar appears: the last one is what the user
        // is looking at now, so it is the one to act on.
        let router = AppRouter()
        router.open(.dailyReminder(.diary))
        router.open(.doseReminder(medicationIds: [UUID()], slot: Date()))

        #expect(router.selectedTab == .today)
        if case .doseReminder = router.consumeDeepLink() {} else {
            Issue.record("expected the dose reminder to win")
        }
    }

    // MARK: - Sheets

    @Test("dismissSheet закрывает и обычный лист, и полноэкранный")
    func testDismissClearsBothPresentations() {
        // They are separate properties, and a dose modal opens the full-screen
        // one while a reminder opens the sheet — a dismiss that cleared only one
        // would leave whichever it missed on screen.
        let router = AppRouter()
        router.present(.diaryCheckIn)
        router.presentFullScreen(.bloodPressureEntry)

        router.dismissSheet()

        #expect(router.activeSheet == nil)
        #expect(router.activeFullScreen == nil)
    }
}
