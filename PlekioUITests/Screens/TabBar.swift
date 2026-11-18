//
//  TabBar.swift
//  PlekioUITests
//
//  Created by Edward Gasparian on 18.11.2026.
//

import XCTest

/// Tabs are found by title: an identifier on a SwiftUI `tabItem` doesn't reach
/// the tab bar, and the tab bar lists each button more than once on iOS 26 and
/// later, so neither a count nor a position is reliable. The app runs in English
/// under test (see `launchPlekio`), so the titles are stable.
@MainActor
struct TabBar {

    enum Tab: String, CaseIterable {
        case today = "Today"
        case diary = "Diary"
        case courses = "Courses"
        case settings = "Settings"
    }

    let app: XCUIApplication

    func button(_ tab: Tab) -> XCUIElement {
        app.tabBars.buttons[tab.rawValue].firstMatch
    }

    /// The tab's button in its selected state; exists only while the tab is open.
    func selectedButton(_ tab: Tab) -> XCUIElement {
        app.tabBars.buttons
            .matching(NSPredicate(format: "label == %@ AND selected == true", tab.rawValue))
            .firstMatch
    }

    func open(_ tab: Tab) {
        button(tab).tap()
    }

    @discardableResult
    func openToday() -> TodayScreen {
        open(.today)
        return TodayScreen(app: app)
    }

    @discardableResult
    func openCourses() -> CoursesScreen {
        open(.courses)
        return CoursesScreen(app: app)
    }
}
