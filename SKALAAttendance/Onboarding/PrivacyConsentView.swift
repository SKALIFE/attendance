import SwiftUI

/// Onboarding privacy consent section (DESIGN.md §4 `OnboardingSection`).
///
/// Wraps the existing analytics toggle with a `lock.shield`-led header and
/// the disclosure lines that explain what is and is not collected. The
/// binding still routes through `state.setAnalyticsEnabled(_:)` so opt-in
/// install/app-launch events fire on the same path as settings.
struct PrivacyConsentView: View {
    @EnvironmentObject private var state: AppState

    static let disclosureLines = [
        "앱 개선을 위해 다음 정보만 전송합니다.",
        "• 익명 설치 식별자",
        "• 앱 실행",
        "• 출결 페이지 열기",
        "• 앱 버전과 macOS 버전",
        "Google 계정, 이름, 이메일, 출결 기록, 방문한 페이지 내용과 Chrome 데이터는 수집하지 않습니다.",
        "설정에서 언제든 끌 수 있습니다."
    ]

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.s2) {
                Toggle("익명 사용 통계 보내기", isOn: Binding(
                    get: { state.preferences.analyticsEnabled },
                    set: { value in
                        Task {
                            await state.setAnalyticsEnabled(value)
                        }
                    }
                ))
                .accessibilityHint("켜면 익명 설치 식별자와 앱 사용 횟수만 전송됩니다.")
                Divider()
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.s1) {
                    ForEach(Self.disclosureLines, id: \.self) { line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignTokens.Spacing.s1)
        } label: {
            Label("익명 사용 통계", systemImage: "lock.shield")
                .font(.headline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
        }
    }
}
