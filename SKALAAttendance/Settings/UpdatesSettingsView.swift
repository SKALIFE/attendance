import SwiftUI

/// 업데이트 settings tab (DESIGN.md §4 `SettingsSection`).
///
/// Preserves the existing automatic-update-check toggle, manual-check
/// action, and current-version label. The toggle still writes both
/// `state.preferences.automaticUpdateChecks` and
/// `state.updater.automaticallyChecksForUpdates` and persists immediately.
struct UpdatesSettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Section {
                Toggle("자동 업데이트 확인", isOn: Binding(
                    get: { state.preferences.automaticUpdateChecks },
                    set: { value in
                        state.preferences.automaticUpdateChecks = value
                        state.updater.automaticallyChecksForUpdates = value
                        state.savePreferences()
                    }
                ))
            } header: {
                Label("자동 확인", systemImage: "arrow.up.circle")
            } footer: {
                Text("Sparkle이 EdDSA 서명이 검증된 업데이트만 설치합니다.")
            }

            Section {
                Button {
                    state.updater.checkForUpdates()
                } label: {
                    Label("지금 업데이트 확인", systemImage: "magnifyingglass")
                }
            } header: {
                Label("수동 확인", systemImage: "arrow.triangle.2.circlepath")
            }

            Section {
                LabeledContent("현재 버전", value: Self.appVersion)
            } header: {
                Label("버전", systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
