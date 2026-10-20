import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var store: AppStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Task {
            await Self.store?.start()
        }
    }
}

@main
struct StackMirrorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AppStore

    init() {
        let store = AppStore()
        _store = StateObject(wrappedValue: store)
        AppDelegate.store = store
    }

    var body: some Scene {
        WindowGroup("StackMirror", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Calendar") {
                    Task { await store.refreshDrafts() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        MenuBarExtra("StackMirror", systemImage: store.menuBarIcon) {
            MenuBarView()
                .environmentObject(store)
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
