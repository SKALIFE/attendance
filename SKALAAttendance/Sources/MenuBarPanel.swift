import SwiftUI

struct MenuBarPanel: View {
    @ObservedObject var controller: AttendanceWindowController

    var body: some View {
        VStack(spacing: 10) {
            Text("SKALA Attendance")
                .font(.headline)

            Button {
                controller.openAttendance()
            } label: {
                Label("출결 열기", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: 8) {
                Button {
                    controller.bringToFront()
                } label: {
                    Label("앞으로", systemImage: "macwindow.on.rectangle")
                }
                .disabled(!controller.isWindowVisible)

                Button {
                    controller.reload()
                } label: {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }
                .disabled(!controller.isWindowVisible)
            }

            Divider()

            Label(controller.statusText, systemImage: controller.statusSymbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Button("종료", role: .destructive) {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}
