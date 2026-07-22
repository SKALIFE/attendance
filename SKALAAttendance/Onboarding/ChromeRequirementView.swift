import SwiftUI

/// Onboarding Chrome requirement section (DESIGN.md §4 `OnboardingSection`).
///
/// Renders inside a `GroupBox` with the `checkmark.rectangle` header. The
/// section explains why the dedicated Chrome is required, shows an
/// installed/missing status line paired with a symbol and Korean text, and
/// exposes the existing download plus retry actions. The retry action still
/// uses `ChromeLocator().findChromeApp()` so onboarding gates completion on
/// a real install.
struct ChromeRequirementView: View {
    @Binding var chromeInstalled: Bool

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.s2) {
                Text("이 앱은 Google 로그인과 패스키를 안전하게 사용하기 위해 설치된 Google Chrome을 사용합니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                statusLine
                HStack(spacing: DesignTokens.Spacing.s2) {
                    Button {
                        NSWorkspace.shared.open(AppConstants.chromeDownloadURL)
                    } label: {
                        Label("Chrome 다운로드 페이지 열기", systemImage: "arrow.up.right.square")
                    }
                    Button("다시 확인") {
                        refreshChromeStatus()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignTokens.Spacing.s1)
        } label: {
            Label("Chrome 확인", systemImage: "checkmark.rectangle")
                .font(.headline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
        }
        .onAppear(perform: refreshChromeStatus)
    }

    private var statusLine: some View {
        HStack(spacing: DesignTokens.Spacing.s2) {
            Image(systemName: chromeInstalled ? "checkmark.circle" : "exclamationmark.triangle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(chromeInstalled ? .green : .orange)
                .accessibilityHidden(true)
            Text(chromeInstalled
                ? "Google Chrome을 찾았습니다."
                : "Google Chrome이 필요합니다. 설치 후 다시 확인해 주세요.")
                .font(.callout.weight(.medium))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chromeInstalled ? "Chrome 설치됨" : "Chrome 미설치")
    }

    private func refreshChromeStatus() {
        chromeInstalled = (try? ChromeLocator().findChromeApp()) != nil
    }
}
