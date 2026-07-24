import SwiftUI

@main
struct SKALAAttendanceApp: App {
    @StateObject private var controller = AttendanceController()
    @StateObject private var updater = UpdateController()

    var body: some Scene {
        MenuBarExtra("SKALA 출결", systemImage: "checkmark.seal.fill") {
            VStack(spacing: 0) {
                WebViewPanel(webView: controller.webView)
                    .frame(width: 390, height: 710)

                Divider()

                HStack(spacing: 12) {
                    Button {
                        controller.reload()
                    } label: {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }

                    Button {
                        updater.checkForUpdates()
                    } label: {
                        Label("업데이트", systemImage: "arrow.up.circle")
                    }

                    Spacer()

                    Button(role: .destructive) {
                        NSApp.terminate(nil)
                    } label: {
                        Label("종료", systemImage: "power")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .font(.system(size: 12))
            }
            .frame(width: 390, height: 780)
        }
        .menuBarExtraStyle(.window)
    }
}
