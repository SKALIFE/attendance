import SwiftUI

/// First-run onboarding window (DESIGN.md §3, §4 `OnboardingSection`).
///
/// Retains the existing 520 pt baseline width and 24 pt outer padding, and
/// presents the unofficial-app notice and no-automation promise before the
/// Chrome, analytics, and login-item choices. The single completion action
/// is the bordered-prominent `Google 로그인 및 시작` button; it stays
/// disabled until onboarding's Chrome requirement is met. The completion
/// path still calls `state.completeOnboarding()` then
/// `state.openAttendance()`.
struct OnboardingView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var chromeInstalled = false
    private let model = OnboardingModel()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s6) {
            Text("SKALA Attendance 시작")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            introBlock
            ChromeRequirementView(chromeInstalled: $chromeInstalled)
            PrivacyConsentView()
            LoginItemChoiceView()
            HStack(spacing: DesignTokens.Spacing.s3) {
                Spacer()
                Button {
                    Task {
                        await state.completeOnboarding()
                        await state.openAttendance()
                    }
                    dismiss()
                } label: {
                    Label("Google 로그인 및 시작", systemImage: "arrow.up.right.square")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!chromeInstalled)
                .accessibilityHint("전용 Chrome을 모바일 환경으로 실행하여 출결 페이지를 엽니다.")
            }
        }
        .padding(DesignTokens.Onboarding.outerPadding)
        .frame(
            width: DesignTokens.Onboarding.width,
            alignment: .topLeading
        )
        .background(Color.skalaCanvas)
        .task {
            if !state.onboardingShouldBePresented {
                dismiss()
            }
        }
        .onDisappear {
            state.cancelOnboardingReplay()
        }
    }

    @ViewBuilder
    private var introBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s2) {
            Text(model.disclaimer)
                .font(.body)
            Text(model.noAutomation)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
