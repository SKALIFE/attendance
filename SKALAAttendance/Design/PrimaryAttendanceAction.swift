import SwiftUI

/// The menu-bar panel's primary attendance action (DESIGN.md §4
/// `PrimaryAttendanceAction`).
///
/// Renders the `checkmark.rectangle` symbol plus the `출결 페이지 열기`
/// Korean label as a bordered-prominent button. The button disables itself
/// while a mutually exclusive launch is running, and shows compact progress
/// plus status text while busy so the user can see what is happening.
struct PrimaryAttendanceAction: View {
    let status: AppStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.s2) {
                Label("출결 페이지 열기", systemImage: "checkmark.rectangle")
                    .labelStyle(.titleAndIcon)
                    .font(.body.weight(.semibold))
                if statusPanel.isLaunching {
                    HStack(spacing: DesignTokens.Spacing.s2) {
                        ProgressView()
                            .controlSize(.small)
                        Text(status.displayText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.s1)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(statusPanel.isLaunching)
        .accessibilityLabel("출결 페이지 열기")
        .accessibilityHint("전용 Chrome을 모바일 환경으로 실행하여 출결 페이지를 엽니다.")
    }

    private var statusPanel: PanelStatus {
        PanelStatus(status: status)
    }
}
