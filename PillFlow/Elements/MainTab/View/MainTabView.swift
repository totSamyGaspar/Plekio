//
//  MainTabView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var router: AppRouter

    /// The one write-failure alert for the whole app, instead of the same
    /// `.alert` repeated across seven screens.
    @ObservedObject private var errorPresenter = AppErrorPresenter.shared

    static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let neonMint = UIColor(Color.neonMint)
        appearance.stackedLayoutAppearance.selected.iconColor = neonMint
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: neonMint]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            DashboardView()
                .tabItem { Label("Today", systemImage: "calendar.day.timeline.left") }
                .tag(0)

            NavigationStack(path: $router.coursesPath) {
                CoursesListView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .courseDetail(let courseId):
                            CourseDetailDestination(courseId: courseId)
                        }
                    }
            }
            .tabItem { Label("Courses", systemImage: "list.clipboard.fill") }
            .tag(1)

            NavigationStack {
                DiaryView()
            }
            .tabItem { Label("Diary", systemImage: "text.book.closed.fill") }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(3)
        }
        .tint(.neonMint)
        .preferredColorScheme(.dark)
        .sheet(item: $router.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .fullScreenCover(item: $router.activeFullScreen) { sheet in
            sheetContent(for: sheet)
        }
        .onChange(of: router.selectedTab) { _, _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
        // Handled here rather than in DashboardView: this screen presents the modal
        // and stays alive as long as the app is open.
        //
        // Both entry points are needed. On a cold start the payload is set before this
        // view reaches the hierarchy, and onChange only sees changes made while the
        // view is alive — so .task takes the value already waiting, onChange the ones
        // arriving later. The pause is not cosmetic: on a cold start this screen
        // appears inside the transition from ContentView, and SwiftUI drops a
        // fullScreenCover requested while the presenting view is still appearing.
        .task {
            try? await Task.sleep(for: .seconds(RootTransition.presentationDelay))
            consumePendingPush()
        }
        .onChange(of: router.pendingPushMedicationIds) { _, _ in consumePendingPush() }
        .alert(
            "Couldn't save",
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

    // MARK: - Push

    private func consumePendingPush() {
        guard let (medicationIds, scheduledTime) = router.consumePendingPush() else { return }

        let dbService = DIContainer.shared.resolve(DatabaseServiceProtocol.self)
        let notificationService = DIContainer.shared.resolve(NotificationServiceProtocol.self)

        // Doses come from the schedule by slot time, not from the dashboard view
        // model: the modal used to depend on whether the dashboard was rendered and
        // on which date it was showing.
        let pills = PendingDose.unlogged(
            medicationIds: medicationIds,
            scheduledTime: scheduledTime,
            in: dbService
        )
        guard !pills.isEmpty else { return }

        router.presentFullScreen(
            .takePill(
                pills: pills,
                onTake: {
                    PendingDose.markTaken(
                        pills,
                        dbService: dbService,
                        notificationService: notificationService
                    )
                },
                onSkip: {
                    for pill in pills {
                        notificationService.cancelNotifications(for: pill.medicationId)
                    }
                }
            )
        )
    }

    @ViewBuilder
    private func sheetContent(for sheet: SheetRoute) -> some View {
        switch sheet {

        case .newTreatment:
            NewTreatmentView()
                .preferredColorScheme(.dark)

        case .takePill(let pills, let onTake, let onSkip):
            TakePillModalView(pills: pills, onTake: {
                onTake()
                router.dismissSheet()
            }, onSkip: {
                onSkip()
                router.dismissSheet()
            }, onSnooze: {
                let notifService = DIContainer.shared.resolve(NotificationServiceProtocol.self)
                let ids = pills.map { $0.medicationId.uuidString }
                let names = pills.map { $0.name }
                notifService.scheduleSnooze(for: ids, names: names)
                router.dismissSheet()
            })
            .presentationBackground(.clear)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppRouter())
}
