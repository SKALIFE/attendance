import SwiftUI

let analyticsPrivacyDisclosure = "익명 사용 통계를 켜면 앱은 기기에 영구 저장되는 익명 설치 ID와 설치·앱 실행·출결 화면 열기, 웹뷰 연결 실패, 업데이트 확인·다운로드·설치 상태 이벤트를 전송합니다. 각 이벤트에는 앱 버전과 빌드 번호, macOS 버전, arm64 아키텍처 정보가 포함됩니다. 계정 정보, 출결 내역, 실제 방문 주소, 페이지 내용, 쿠키, 토큰은 수집하지 않습니다."

@main
struct SKALAAttendanceApp: App {
    @StateObject private var controller = AttendanceController()
    @StateObject private var updater = UpdateController()
    @State private var showsSettingsPopover = false

    private var analyticsBinding: Binding<Bool> {
        Binding(
            get: { controller.analyticsEnabled },
            set: { controller.analyticsEnabled = $0 }
        )
    }

    var body: some Scene {
        MenuBarExtra("SKALA 출결", systemImage: "checkmark.seal.fill") {
            VStack(spacing: 0) {
                WebViewPanel(webView: controller.webView)
                    .frame(width: 390, height: 710)

                Divider()

                HStack(spacing: 14) {
                    Button {
                        controller.reload()
                    } label: {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }
                    .labelStyle(.iconOnly)
                    .help("새로고침")
                    .accessibilityLabel("새로고침")

                    Button {
                        updater.checkForUpdates()
                    } label: {
                        Label("업데이트 확인", systemImage: "arrow.up.circle")
                    }
                    .labelStyle(.iconOnly)
                    .help("업데이트 확인")
                    .accessibilityLabel("업데이트 확인")

                    Spacer()

                    Button {
                        showsSettingsPopover.toggle()
                    } label: {
                        Label("설정", systemImage: "gearshape")
                    }
                    .labelStyle(.iconOnly)
                    .help("설정")
                    .accessibilityLabel("설정")
                    .popover(isPresented: $showsSettingsPopover, arrowEdge: .bottom) {
                        PrivacySettingsPopover(
                            analyticsEnabled: analyticsBinding
                        )
                    }

                    Button(role: .destructive) {
                        NSApp.terminate(nil)
                    } label: {
                        Label("종료", systemImage: "power")
                    }
                    .labelStyle(.iconOnly)
                    .help("종료")
                    .accessibilityLabel("종료")
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

private struct PrivacySettingsPopover: View {
    @Binding var analyticsEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("익명 사용 통계", isOn: $analyticsEnabled)
                .font(.system(size: 12, weight: .medium))

            Text(analyticsPrivacyDisclosure)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .accessibilityLabel(analyticsPrivacyDisclosure)
        }
        .padding(12)
        .frame(width: 264)
    }
}
