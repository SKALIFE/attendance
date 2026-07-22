import SwiftUI

/// 정보 settings tab (DESIGN.md §4 `SettingsSection`).
///
/// Presents the app name, version, license, the unofficial-app notice, and
/// the existing GitHub link. All actions are preserved.
struct AboutSettingsView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("이름", value: AppConstants.appName)
                LabeledContent("버전", value: version)
                LabeledContent("라이선스", value: "MIT")
            } header: {
                Label("앱 정보", systemImage: "info.circle")
            }

            Section {
                Text("비공식 오픈소스 편의 도구입니다. SKALA 또는 SK AX가 제공하는 공식 앱이 아닙니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Label("고지", systemImage: "exclamationmark.bubble")
            }

            Section {
                Button {
                    NSWorkspace.shared.open(AppConstants.repositoryURL)
                } label: {
                    Label("GitHub 저장소", systemImage: "arrow.up.right.square")
                }
            } header: {
                Label("링크", systemImage: "link")
            }
        }
        .formStyle(.grouped)
    }
}
