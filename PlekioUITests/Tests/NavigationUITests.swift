//
//  NavigationUITests.swift
//  PlekioUITests
//
//  Created by Edward Gasparian on 18.11.2026.
//

import XCTest

final class NavigationUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEveryTabOpens() {
        let app = XCUIApplication.launchPlekio()
        let tabBar = TabBar(app: app)

        for tab in TabBar.Tab.allCases {
            tabBar.open(tab)
            assertExists(tabBar.selectedButton(tab), in: app, "\(tab.rawValue) didn't open")
        }
    }
}
