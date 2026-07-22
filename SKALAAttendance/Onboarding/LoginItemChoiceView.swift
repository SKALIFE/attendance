import SwiftUI

/// Onboarding login-item choice section (DESIGN.md §4 `OnboardingSection`).
///
/// Wraps the existing `로그인 시 자동 실행` toggle with a header and helper
/// text that explains where the user can change it later. The binding still
/// routes through `state.setLaunchAtLogin(_:)` so the underlying
/// `SMAppService.mainApp` registration path is unchanged.
struct LoginItemChoiceView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.s2) {
                Toggle("로그인 시 자동 실행", isOn: Binding(
                    get: { state.preferences.launchAtLoginEnabled },
                    set: { value in
                        state.setLaunchAtLogin(value)
                    }
                ))
                .accessibilityHint("이 Mac에 로그인할 때마다 SKALA Attendance를 실행합니다.")
                Text("시스템 설정의 일반 → 로그인 항목에서 언제든 변경할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignTokens.Spacing.s1)
        } label: {
            Label("로그인 시 자동 실행", systemImage: "power")
                .font(.headline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
        }
    }
}
