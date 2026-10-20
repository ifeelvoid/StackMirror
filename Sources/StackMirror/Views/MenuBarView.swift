import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(store.statusMessage)
            .lineLimit(1)

        Divider()

        Button("Open StackMirror") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }

        Button("Refresh Calendar") {
            Task { await store.refreshDrafts() }
        }
        .disabled(store.isRefreshingDrafts)

        Divider()

        Button("Settings…") { openSettings() }
        Button("Quit") { NSApp.terminate(nil) }
    }
}
