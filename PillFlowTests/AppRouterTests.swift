//
//  AppRouterTests.swift
//  PillFlowTests
//
//  Tests for where a tapped notification takes the user. The router is the one
//  piece of that journey with no UIKit or notification centre in it, so it is
//  the piece that can be checked without a device.
//

import Testing
import Foundation
@testable import PillFlow

@MainActor
@Suite("AppRouter Tests")
struct AppRouterTests {

    // MARK: - Reminders

    @Test("напоминание о давлении ведёт в дневник, на вкладку с показаниями")
    func testBloodPressureReminderDeepLinksToTrends() async throws {
        let router = AppRouter()

        router.handleReminder(.bloodPressure)

        #expect(router.selectedTab == 2)
        #expect(router.pendingReminder == .bloodPressure)
        // Behind the entry form: dismissing it should leave the new measurement
        // on screen, not the journal feed.
        #expect(router.pendingDiarySubTab == .moodTrends)
    }

    @Test("напоминание дневника не переключает подвкладку")
    func testDiaryReminderLeavesTheSubTabAlone() async throws {
        let router = AppRouter()

        router.handleReminder(.diary)

        #expect(router.selectedTab == 2)
        #expect(router.pendingReminder == .diary)
        // The check-in is not about any one sub-tab, so the diary opens wherever
        // the user left it.
        #expect(router.pendingDiarySubTab == nil)
    }

    @Test("запрос забирается один раз")
    func testPendingReminderIsConsumedOnce() async throws {
        // Consumed rather than read: the sheet is presented from a .task and an
        // .onChange, and both run for the same tap. A request that survived
        // being read would present the form twice.
        let router = AppRouter()
        router.handleReminder(.bloodPressure)

        #expect(router.consumePendingReminder() == .bloodPressure)
        #expect(router.consumePendingReminder() == nil)

        #expect(router.consumePendingDiarySubTab() == .moodTrends)
        #expect(router.consumePendingDiarySubTab() == nil)
    }

    @Test("без запроса потребление ничего не возвращает")
    func testNothingToConsumeByDefault() async throws {
        let router = AppRouter()

        #expect(router.consumePendingReminder() == nil)
        #expect(router.consumePendingDiarySubTab() == nil)
        #expect(router.consumePendingPush() == nil)
    }

    // MARK: - Dose push

    @Test("пуш о приёме ведёт на сегодняшний экран и переносит слот целиком")
    func testDosePushCarriesItsSlot() async throws {
        let router = AppRouter()
        let ids = [UUID(), UUID()]
        let time = Date(timeIntervalSince1970: 1_780_000_000)

        router.handlePushNotification(medicationIds: ids, time: time)

        #expect(router.selectedTab == 0)

        let consumed = try #require(router.consumePendingPush())
        #expect(consumed.0 == ids)
        #expect(consumed.1 == time)
        #expect(router.consumePendingPush() == nil)
    }

    // MARK: - Sheets

    @Test("dismissSheet закрывает и обычный лист, и полноэкранный")
    func testDismissClearsBothPresentations() async throws {
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
