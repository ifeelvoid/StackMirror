import Foundation
import ServiceManagement
import UserNotifications

struct LaunchAtLoginService: Sendable {
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
    }

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}

struct NotificationService: Sendable {
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func failure(_ message: String) async {
        let content = UNMutableNotificationContent()
        content.title = "StackMirror needs attention"
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
