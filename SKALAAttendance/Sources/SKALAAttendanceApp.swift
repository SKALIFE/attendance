import SwiftUI

extension Notification.Name {
    static let openAttendance = Notification.Name("SKALAAttendance.openAttendance")
}

@main
struct SKALAAttendanceApp: App {
    @StateObject private var controller = AttendanceWindowController()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("SKALA 출결", systemImage: "checkmark.seal.fill") {
            MenuBarPanel(controller: controller)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first, url.host == "open" else { return }
        NotificationCenter.default.post(name: .openAttendance, object: nil)
    }
}
