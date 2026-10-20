import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection: SidebarSection? = .calendar

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("StackMirror")
        } detail: {
            Group {
                switch selection ?? .calendar {
                case .calendar:
                    CalendarView()
                case .composer:
                    ComposerView()
                case .campaigns:
                    CampaignsView()
                case .analytics:
                    AnalyticsView()
                case .engagement:
                    EngagementView()
                case .subscriptions:
                    LibraryView()
                }
            }
            .environmentObject(store)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await store.refreshDrafts() }
                } label: {
                    Label("Refresh Calendar", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshingDrafts)
            }
        }
    }
}
