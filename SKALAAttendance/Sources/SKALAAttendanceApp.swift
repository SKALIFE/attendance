import SwiftUI

let analyticsPrivacyDisclosure = "익명 사용 통계를 켜면 앱은 이 Mac에 영구 저장되는 임의 설치 ID와 앱 실행마다 새로 생성되어 종료 시 폐기되는 임의 세션 ID를 전송합니다. 설치·앱 실행·일일 활성 상태·출결 화면 열기, 웹뷰 연결 실패, 업데이트 확인·다운로드·설치 상태 이벤트에는 분석 형식 버전, 앱 버전과 빌드 번호, macOS 버전, arm64 아키텍처가 포함됩니다. 계정 정보, 인증 설정, 출결 내역, 실제 방문 주소, 페이지 내용, 쿠키, 토큰, Wi-Fi·유선 연결 여부, 하드웨어 식별자는 전송하지 않습니다. 분석 요청을 전달하는 과정에서 서비스 제공자는 IP 주소를 처리할 수 있습니다."
let analyticsPrivacySummary = "앱 개선을 위한 익명 사용·오류 정보만 전송합니다."

private struct AuthenticationClassOption: Identifiable {
    let code: String
    let label: String

    var id: String { code }
}

private struct AuthenticationRegionOption: Identifiable {
    let code: String
    let label: String
    let classes: [AuthenticationClassOption]

    var id: String { code }
}

private let authenticationRegions = [
    AuthenticationRegionOption(
        code: "P1",
        label: "판교캠퍼스 4F",
        classes: [
            AuthenticationClassOption(code: "1", label: "1반"),
            AuthenticationClassOption(code: "2", label: "2반"),
            AuthenticationClassOption(code: "3", label: "3반"),
            AuthenticationClassOption(code: "4", label: "4반"),
            AuthenticationClassOption(code: "5", label: "5반"),
        ]
    ),
    AuthenticationRegionOption(
        code: "P2",
        label: "판교캠퍼스 5F",
        classes: [
            AuthenticationClassOption(code: "6", label: "6반"),
            AuthenticationClassOption(code: "7", label: "7반"),
            AuthenticationClassOption(code: "8", label: "8반"),
            AuthenticationClassOption(code: "9", label: "9반"),
            AuthenticationClassOption(code: "10", label: "10반"),
        ]
    ),
    AuthenticationRegionOption(
        code: "KJ",
        label: "광주캠퍼스",
        classes: [
            AuthenticationClassOption(code: "11", label: "1반"),
            AuthenticationClassOption(code: "12", label: "2반"),
            AuthenticationClassOption(code: "13", label: "3반"),
            AuthenticationClassOption(code: "14", label: "4반"),
        ]
    ),
    AuthenticationRegionOption(
        code: "US",
        label: "울산캠퍼스",
        classes: [
            AuthenticationClassOption(code: "15", label: "1반"),
            AuthenticationClassOption(code: "16", label: "2반"),
            AuthenticationClassOption(code: "17", label: "3반"),
            AuthenticationClassOption(code: "18", label: "4반"),
        ]
    ),
]

@main
struct SKALAAttendanceApp: App {
    @StateObject private var controller = AttendanceController()
    @StateObject private var updater = UpdateController()
    @AppStorage("authenticationProfileName") private var authenticationName = ""
    @AppStorage("authenticationProfileRegion") private var authenticationRegionCode = ""
    @AppStorage("authenticationProfileClass") private var authenticationClassCode = ""
    @State private var showsSettingsPopover = false
    @State private var showsAuthenticationFillError = false
    @State private var authenticationFillErrorMessage = ""

    private var analyticsBinding: Binding<Bool> {
        Binding(
            get: { controller.analyticsEnabled },
            set: { controller.analyticsEnabled = $0 }
        )
    }

    private var selectedAuthenticationRegion: AuthenticationRegionOption? {
        authenticationRegions.first { $0.code == authenticationRegionCode }
    }

    private var isAuthenticationProfileComplete: Bool {
        !authenticationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedAuthenticationRegion?.classes.contains {
                $0.code == authenticationClassCode
            } == true
    }

    private var authenticationFillHelp: String {
        if !isAuthenticationProfileComplete {
            return "설정에서 인증 정보를 저장해 주세요"
        }
        if !controller.isAuthenticationPage {
            return "인증 화면에서 사용할 수 있습니다"
        }
        return "저장한 인증 정보 입력"
    }

    var body: some Scene {
        MenuBarExtra("SKALA 출결", systemImage: "checkmark.seal.fill") {
            VStack(spacing: 0) {
                WebViewPanel(webView: controller.webView)
                    .frame(width: 390, height: 710)

                Divider()

                HStack(spacing: 14) {
                    Button {
                        controller.returnToAttendance()
                    } label: {
                        Label("출결 홈", systemImage: "house")
                    }
                    .labelStyle(.iconOnly)
                    .help("출결 홈으로")
                    .accessibilityLabel("출결 홈으로")

                    Button {
                        controller.reload()
                    } label: {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }
                    .labelStyle(.iconOnly)
                    .help("새로고침")
                    .accessibilityLabel("새로고침")

                    Spacer()

                    Button {
                        Task { @MainActor in
                            let result = await controller.fillAuthenticationProfile(
                                name: authenticationName,
                                regionCode: authenticationRegionCode,
                                classCode: authenticationClassCode
                            )
                            if let message = result.failureMessage {
                                authenticationFillErrorMessage = message
                                showsAuthenticationFillError = true
                            }
                        }
                    } label: {
                        Label("인증 정보 입력", systemImage: "person.text.rectangle")
                    }
                    .labelStyle(.iconOnly)
                    .help(authenticationFillHelp)
                    .accessibilityLabel("저장한 인증 정보 입력")
                    .disabled(
                        !isAuthenticationProfileComplete
                            || !controller.isAuthenticationPage
                    )

                    Button {
                        showsSettingsPopover.toggle()
                    } label: {
                        Label("설정", systemImage: "gearshape")
                    }
                    .labelStyle(.iconOnly)
                    .help("설정")
                    .accessibilityLabel("설정")
                    .popover(isPresented: $showsSettingsPopover, arrowEdge: .bottom) {
                        SettingsPopover(
                            authenticationName: $authenticationName,
                            authenticationRegionCode: $authenticationRegionCode,
                            authenticationClassCode: $authenticationClassCode,
                            analyticsEnabled: analyticsBinding,
                            checkForUpdates: {
                                updater.checkForUpdates()
                            }
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
                .alert(
                    "인증 정보 입력 실패",
                    isPresented: $showsAuthenticationFillError
                ) {
                    Button("확인", role: .cancel) {
                    }
                } message: {
                    Text(authenticationFillErrorMessage)
                }
            }
            .frame(width: 390, height: 780)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct SettingsPopover: View {
    @Binding var authenticationName: String
    @Binding var authenticationRegionCode: String
    @Binding var authenticationClassCode: String
    @Binding var analyticsEnabled: Bool
    let checkForUpdates: () -> Void

    private var selectedRegion: AuthenticationRegionOption? {
        authenticationRegions.first { $0.code == authenticationRegionCode }
    }

    private var regionBinding: Binding<String> {
        Binding(
            get: { authenticationRegionCode },
            set: { newRegionCode in
                authenticationRegionCode = newRegionCode
                guard let newRegion = authenticationRegions.first(where: {
                    $0.code == newRegionCode
                }) else {
                    authenticationClassCode = ""
                    return
                }
                if !newRegion.classes.contains(where: {
                    $0.code == authenticationClassCode
                }) {
                    authenticationClassCode = ""
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("인증 정보")
                .font(.system(size: 12, weight: .semibold))

            TextField("이름", text: $authenticationName)
                .textFieldStyle(.roundedBorder)

            Picker("지역", selection: regionBinding) {
                Text("선택").tag("")
                ForEach(authenticationRegions) { region in
                    Text(region.label).tag(region.code)
                }
            }
            .pickerStyle(.menu)

            Picker("반", selection: $authenticationClassCode) {
                Text("선택").tag("")
                ForEach(selectedRegion?.classes ?? []) { classOption in
                    Text(classOption.label).tag(classOption.code)
                }
            }
            .pickerStyle(.menu)
            .disabled(selectedRegion == nil)

            Text("이 Mac에만 저장됩니다. 인증 화면에서 사람 아이콘을 눌러 입력하세요.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Toggle("익명 사용 통계", isOn: $analyticsEnabled)
                .font(.system(size: 12, weight: .medium))

            Text(analyticsPrivacySummary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup("수집 정보 보기") {
                Text(analyticsPrivacyDisclosure)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .font(.system(size: 11))

            Divider()

            Button(action: checkForUpdates) {
                Label("업데이트 확인", systemImage: "arrow.up.circle")
            }
            .font(.system(size: 12))
        }
        .padding(12)
        .frame(width: 280)
    }
}
