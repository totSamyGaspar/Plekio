//
//  MainTabView.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI

struct MainTabView: View {

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies
    @EnvironmentObject var router: AppRouter

    /// App-wide write-failure alert; observed via `@Observable` when `message` is read in body.
    private var errorPresenter: AppErrorPresenter { dependencies.errorPresenter }

    // MARK: - Appearance

    static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()

        if UIAccessibility.isReduceTransparencyEnabled {
            // Read once: a mid-session change to the setting applies on next launch.
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .appSurfaceOpaque
        } else {
            appearance.configureWithDefaultBackground()
            // Plain material (not ...Dark) resolves per trait, so it follows the theme.
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            appearance.backgroundColor = .appTabBarWash
        }

        appearance.stackedLayoutAppearance.selected.iconColor = .appAccent
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.appAccent]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                DashboardView(viewModel: dependencies.makeDashboardViewModel())
            }
            .tabItem { Label("Today", systemImage: "calendar.day.timeline.left") }
            .tag(AppTab.today)

            NavigationStack {
                DiaryView(viewModel: dependencies.makeDiaryViewModel())
            }
            .tabItem { Label("Diary", systemImage: "text.book.closed.fill") }
            .tag(AppTab.diary)

            NavigationStack(path: $router.coursesPath) {
                CoursesListView(viewModel: dependencies.makeCoursesListViewModel())
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .courseDetail(let courseId):
                            CourseDetailDestination(courseId: courseId)
                        }
                    }
            }
            .tabItem { Label("Courses", systemImage: "list.clipboard.fill") }
            .tag(AppTab.courses)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(AppTab.settings)
        }
        .tint(.accentPrimary)
        .appTheme()
        .sheet(item: $router.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .fullScreenCover(item: $router.activeFullScreen) { sheet in
            sheetContent(for: sheet)
        }
        .onChange(of: router.selectedTab) { _, _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
        // .task catches a link set before cold start, onChange later ones. The delay
        // is required: SwiftUI drops a fullScreenCover requested mid-transition.
        .task {
            try? await Task.sleep(for: .seconds(RootTransition.presentationDelay))
            consumeDeepLink()
        }
        .onChange(of: router.pendingDeepLink) { _, _ in consumeDeepLink() }
        .toastOverlay(dependencies.toasts)
        .alert(
            Text(errorPresenter.title),
            isPresented: Binding(
                get: { errorPresenter.message != nil },
                set: { if !$0 { errorPresenter.message = nil } }
            ),
            presenting: errorPresenter.message
        ) { _ in
            Button("OK", role: .cancel) { errorPresenter.message = nil }
        } message: { text in
            Text(text)
        }
    }

    // MARK: - Deep Links

    /// Handled here because this view is always in the hierarchy, even on cold launch.
    private func consumeDeepLink() {
        guard let link = router.consumeDeepLink() else { return }

        switch link {
        case .doseReminder(let medicationIds, let slot):
            // From the schedule, not the dashboard, which may be absent or on another date.
            let pills = dependencies.doseLogging.openDoses(medicationIds: medicationIds, at: slot)
            guard !pills.isEmpty else { return }
            router.presentFullScreen(.takePill(pills: pills))

        case .dailyReminder(.diary):
            router.present(.diaryCheckIn)

        case .dailyReminder(.bloodPressure):
            router.present(.bloodPressureEntry)
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(for sheet: SheetRoute) -> some View {
        switch sheet {

        case .newTreatment:
            NewTreatmentView(viewModel: dependencies.makeNewTreatmentViewModel())
                .appTheme()

        case .diaryCheckIn:
            DiaryCheckInView(viewModel: dependencies.makeDiaryCheckInViewModel())
                .appTheme()

        case .bloodPressureEntry:
            BloodPressureEntryView { measuredAt, systolic, diastolic, pulse in
                if dependencies.bloodPressureLogging.save(
                    measuredAt: measuredAt, systolic: systolic, diastolic: diastolic, pulse: pulse
                ) {
                    dependencies.toasts.show(.success("Blood pressure saved"))
                }
            }
            .appTheme()

        case .takePill(let pills):
            let actions = dependencies.doseSheetActions
            TakePillModalView(pills: pills, onTake: {
                actions.take(pills)
                router.dismissSheet()
            }, onSkip: {
                actions.skip(pills)
                router.dismissSheet()
            }, onSnooze: {
                actions.snooze(pills)
                router.dismissSheet()
            })
            .presentationBackground(.clear)
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AppRouter())
        .environment(AppDependencies.preview)
}
