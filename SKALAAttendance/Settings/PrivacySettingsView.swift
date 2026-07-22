import SwiftUI

/// 개인정보 settings tab (DESIGN.md §4 `SettingsSection`).
///
/// Preserves the existing analytics toggle, anonymous-install-ID reset, and
/// PRIVACY.md open actions. The toggle still routes through
/// `state.setAnalyticsEnabled(_:)` so opt-in install/app-launch events fire
/// on the same path as onboarding.
struct PrivacySettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Section {
                Toggle("익명 사용 통계", isOn: Binding(
                    get: { state.preferences.analyticsEnabled },
                    set: { value in
                        Task {
                            await state.setAnalyticsEnabled(value)
                        }
                    }
                ))
            } header: {
                Label("수집", systemImage: "lock.shield")
            } footer: {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s1) {
                    Text("수집 항목: 익명 설치 식별자, 앱 실행, 출결 페이지 열기, 앱 버전, macOS 버전.")
                    Text("수집하지 않음: Google 계정, 이름, 이메일, 출결 기록, 페이지 내용, 쿠키, 인증 토큰.")
                }
            }

            Section {
                Button {
                    state.preferences.anonymousInstallID = AnonymousInstallID.generate().value
                    state.savePreferences()
                } label: {
                    Label("익명 설치 식별자 재설정", systemImage: "arrow.counterclockwise.circle")
                }
            } header: {
                Label("식별자", systemImage: "person.crop.circle.badge.questionmark")
            } footer: {
                Text("재설정하면 기존 식별자와 연결된 통계가 더 이상 누적되지 않습니다.")
            }

            Section {
                Button {
                    NSWorkspace.shared.open(AppConstants.repositoryURL.appendingPathComponent("blob/main/PRIVACY.md"))
                } label: {
                    Label("개인정보 문서 열기", systemImage: "doc.text")
                }
            } header: {
                Label("문서", systemImage: "book")
            }
        }
        .formStyle(.grouped)
    }
}
