//
//  AppRouter.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.06.2026.
//

import SwiftUI

@MainActor
@Observable
final class AppRouter {

    // MARK: - Properties

    var selectedTab: AppTab = .today
    var coursesPath = NavigationPath()

    var activeSheet: SheetRoute?
    var activeFullScreen: SheetRoute?

    /// Parked for MainTabView: on a cold launch it arrives before the tab bar exists.
    private(set) var pendingDeepLink: DeepLink?

    /// Diary sub-tab to land on; consumed by DiaryView.
    private(set) var pendingDiarySubTab: DiarySubTab?

    // MARK: - Sheet presentation

    func present(_ sheet: SheetRoute) {
        activeSheet = sheet
    }

    func presentFullScreen(_ sheet: SheetRoute) {
        activeFullScreen = sheet
    }

    func dismissSheet() {
        activeSheet = nil
        activeFullScreen = nil
    }

    // MARK: - Navigation

    /// Opens a course's detail on the Courses tab, replacing whatever was pushed there.
    func showCourse(id: UUID) {
        selectedTab = .courses
        coursesPath = NavigationPath([Route.courseDetail(courseId: id)])
    }

    // MARK: - Deep links

    /// Switches to the link's tab and parks it for the screen that presents it.
    func open(_ link: DeepLink) {
        selectedTab = link.tab
        pendingDeepLink = link
        if let subTab = link.diarySubTab {
            pendingDiarySubTab = subTab
        }
    }

    /// Consumed, not read: both a `.task` and an `.onChange` handle the same tap,
    /// so a link that survived a read would be presented twice.
    func consumeDeepLink() -> DeepLink? {
        defer { pendingDeepLink = nil }
        return pendingDeepLink
    }

    func consumePendingDiarySubTab() -> DiarySubTab? {
        defer { pendingDiarySubTab = nil }
        return pendingDiarySubTab
    }
}
