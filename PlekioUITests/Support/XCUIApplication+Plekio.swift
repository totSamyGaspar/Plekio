//
//  XCUIApplication+Plekio.swift
//  PlekioUITests
//
//  Created by Edward Gasparian on 18.11.2026.
//

import XCTest

// MARK: - Seed

/// Mirrors `UITestingLaunch.Seed` in the app. A copy, not the app's type: that
/// file depends on the rest of the app and can't be built into this target.
enum Seed: String {
    case empty, onboarding, today
}

/// Mirrors `UITestingSeed.Names` in the app.
enum SeedNames {
    static let course = "Vitamins"
    static let morning = "Omega-3"
    static let dueNow = "Vitamin D3"
}

// MARK: - Launch

extension XCUIApplication {

    /// Starts Plekio in its UI-testing mode, in English whatever the simulator's
    /// language, so the few checks that read text don't depend on the machine.
    @MainActor
    static func launchPlekio(seed: Seed = .empty) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-ui-seed", seed.rawValue,
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
        return app
    }

    /// The one element with this identifier, whatever its type.
    @MainActor
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}

// MARK: - Waiting

extension XCUIElement {

    /// Long enough for a sheet to open on a slow CI simulator.
    static let timeout: TimeInterval = 5
}

extension XCUIApplication {

    /// Swipes up until `element` is on screen and tappable. Needed below the fold:
    /// Today's dose list is a LazyVStack, so its cards aren't in the hierarchy at
    /// all until they scroll into view.
    @MainActor
    @discardableResult
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 8) -> Bool {
        var swipes = 0
        while !(element.exists && element.isHittable), swipes < maxSwipes {
            swipeUp()
            swipes += 1
        }
        return element.exists && element.isHittable
    }
}

// MARK: - Assertions

extension XCTestCase {

    /// Waits for `element`; on failure attaches the app's accessibility hierarchy
    /// to the test report, so a missing identifier can be seen, not guessed at.
    @MainActor
    func assertExists(
        _ element: XCUIElement,
        in app: XCUIApplication,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard !element.waitForExistence(timeout: XCUIElement.timeout) else { return }
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTFail("Not found: \(element). \(message)", file: file, line: line)
    }
}
