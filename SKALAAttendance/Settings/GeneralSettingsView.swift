import SwiftUI

/// 일반 settings tab (DESIGN.md §4 `SettingsSection`).
///
/// Groups the existing launch-at-login, open-on-menu-click, window-bounds
/// reset, and reload actions into native `Section`s with helper footers.
/// All bindings and actions are preserved: launch-at-login routes through
/// `state.setLaunchAtLogin(_:)`, the open-on-menu-click toggle persists on
/// change, and the reload button still awaits `state.reload()`.
struct GeneralSettingsView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section {
                Toggle("로그인 시 자동 실행", isOn: Binding(
                    get: { state.preferences.launchAtLoginEnabled },
                    set: { value in
                        state.setLaunchAtLogin(value)
                    }
                ))
            } header: {
                Label("실행", systemImage: "power")
            } footer: {
                Text("이 Mac에 로그인할 때마다 SKALA Attendance를 실행합니다. 시스템 설정의 일반 → 로그인 항목에서도 변경할 수 있습니다.")
            }

            Section {
                Toggle("메뉴바 아이콘 클릭 시 바로 출결창 열기", isOn: Binding(
                    get: { state.preferences.openOnMenuClick },
                    set: { value in
                        state.preferences.openOnMenuClick = value
                        state.savePreferences()
                    }
                ))
            } header: {
                Label("메뉴바", systemImage: "checkmark.rectangle")
            } footer: {
                Text("켜면 메뉴바 아이콘을 클릭하는 것만으로 전용 Chrome이 출결 페이지를 엽니다.")
            }

            Section {
                Button {
                    state.beginOnboardingReplay()
                    openWindow(id: "onboarding")
                } label: {
                    Label("최초 설정 다시 보기", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Label("도움말", systemImage: "questionmark.circle")
            } footer: {
                Text("앱의 안내와 설정 선택을 다시 볼 수 있습니다. 닫으면 기존 설정은 유지되며 전용 Chrome 프로필과 로그인 정보는 변경되지 않습니다.")
            }

            Section {
                Button {
                    state.preferences.windowBounds = AppConstants.defaultWindowBounds
                    state.savePreferences()
                } label: {
                    Label("창 위치 초기화", systemImage: "rectangle.center.inset.filled")
                }
                Button {
                    Task { await state.reload() }
                } label: {
                    Label("출결 페이지 새로고침", systemImage: "arrow.clockwise")
                }
            } header: {
                Label("창", systemImage: "macwindow")
            } footer: {
                Text("창 위치를 초기화하면 다음 실행 시 기본 위치와 크기로 열립니다.")
            }
        }
        .formStyle(.grouped)
    }
}
