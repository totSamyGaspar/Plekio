//
//  TourCoordinatorTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 26.09.2026.
//

import Testing
import Foundation
@testable import Plekio
internal import CoreGraphics

@MainActor
@Suite("TourCoordinator")
struct TourCoordinatorTests {

    // MARK: - Helpers

    @MainActor
    private final class Harness {
        let defaults: UserDefaults
        let suite = "PlekioTests.Tour.\(UUID().uuidString)"
        let settings: SettingsStore
        let router = AppRouter()
        var finishCount = 0
        lazy var tour = TourCoordinator(settings: settings, router: router) { [unowned self] in finishCount += 1 }

        init() {
            defaults = UserDefaults(suiteName: suite)!
            settings = SettingsStore(defaults: defaults)
        }

        deinit { UserDefaults().removePersistentDomain(forName: suite) }
    }

    // MARK: - Starting

    @Test("без курсов тур начинается на «Сегодня»")
    func startsOnTodayWithoutCourses() {
        let h = Harness()
        h.router.selectedTab = .settings

        h.tour.startIfNeeded(hasCourses: false)

        #expect(h.tour.step == .intro)
        #expect(h.router.selectedTab == .today)
    }

    @Test("если курсы уже есть, тур не показывается и отмечается пройденным")
    func skippedWhenCoursesExist() {
        let h = Harness()

        h.tour.startIfNeeded(hasCourses: true)

        #expect(h.tour.step == nil)
        #expect(h.settings.hasCompletedTour)
        #expect(h.finishCount == 1)
    }

    @Test("пройденный тур не показывается снова, но подсказки разблокируются")
    func finishedTourNeverRestarts() {
        let h = Harness()
        h.settings.hasCompletedTour = true

        h.tour.startIfNeeded(hasCourses: false)

        #expect(h.tour.step == nil)
        #expect(h.finishCount == 1)
    }

    // MARK: - Flow

    @Test("«Далее» ведёт на Курсы к кнопке +, а шаг ждёт создания курса")
    func nextLeadsToCoursesAndWaits() {
        let h = Harness()
        h.tour.startIfNeeded(hasCourses: false)

        h.tour.next()
        #expect(h.tour.step == .createCourse)
        #expect(h.router.selectedTab == .courses)

        // "Next" can't skip the action step.
        h.tour.next()
        #expect(h.tour.step == .createCourse)
    }

    @Test("созданный курс возвращает на «Сегодня», последний шаг завершает тур")
    func courseCreatedThenFinish() {
        let h = Harness()
        h.tour.startIfNeeded(hasCourses: false)
        h.tour.next()

        h.tour.courseCreated()
        #expect(h.tour.step == .logDose)
        #expect(h.router.selectedTab == .today)

        h.tour.next()
        #expect(h.tour.step == nil)
        #expect(h.settings.hasCompletedTour)
        #expect(h.finishCount == 1)
    }

    @Test("создание курса вне тура ничего не меняет")
    func courseCreatedOutsideTheTourIsIgnored() {
        let h = Harness()
        h.tour.courseCreated()
        #expect(h.tour.step == nil)
        #expect(!h.settings.hasCompletedTour)
    }

    @Test("«Пропустить» завершает тур с любого шага")
    func skipFinishes() {
        let h = Harness()
        h.tour.startIfNeeded(hasCourses: false)
        h.tour.next()

        h.tour.skip()

        #expect(h.tour.step == nil)
        #expect(h.settings.hasCompletedTour)
    }

    @Test("подсветка — рамка цели текущего шага")
    func highlightedFrameFollowsTheStep() {
        let h = Harness()
        let frame = CGRect(x: 300, y: 60, width: 44, height: 44)
        h.tour.update(.newCourseButton, frame: frame)
        h.tour.startIfNeeded(hasCourses: false)

        #expect(h.tour.highlightedFrame == nil)
        h.tour.next()
        #expect(h.tour.highlightedFrame == frame)
    }
}
