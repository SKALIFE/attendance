import SwiftUI

@main
struct SKALAAttendanceApp: App {
    @StateObject private var controller = AttendanceController()

    var body: some Scene {
        MenuBarExtra("SKALA 출결", systemImage: "checkmark.seal.fill") {
            WebViewPanel(webView: controller.webView)
                .frame(width: 390, height: 780)
        }
        .menuBarExtraStyle(.window)
    }
}
