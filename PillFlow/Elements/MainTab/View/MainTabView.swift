//
//  MainTabView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var router: AppRouter

    static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let neonMint = UIColor(Color.mint)
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

            // TAB 1: Courses — NavigationStack
            NavigationStack(path: $router.coursesPath) {
                CoursesListView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .courseDetail(let course):
                            CourseDetailView(course: course)
                        }
                    }
            }
            .tabItem { Label("Courses", systemImage: "list.clipboard.fill") }
            .tag(1)

            // TAB 2: Diary — daily health & mood check-ins
            NavigationStack {
                DiaryView()
            }
            .tabItem { Label("Diary", systemImage: "text.book.closed.fill") }
            .tag(2)

            // TAB 3: Settings
            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(3)
        }
        .tint(.mint)
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
    }

    @ViewBuilder
    private func sheetContent(for sheet: SheetRoute) -> some View {
        switch sheet {

        case .newTreatment:
            NewTreatmentView()
                .preferredColorScheme(.dark)

        case .addMedication(let onSave):
            AddMedicationView { draft in
                onSave(draft)
                router.dismissSheet()
            }
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
                // Snooze the whole batch
                let ids = pills.map { $0.medicationId.uuidString }
                let names = pills.map { $0.name }.joined(separator: ", ")
                notifService.scheduleSnooze(for: ids, combinedNames: names)
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
