import SwiftUI

/// Window-style menu-bar panel (DESIGN.md §3, §4 `MenuPanel`).
///
/// Layout order is fixed by DESIGN.md: identity header, primary action,
/// operational commands, separated status summary, optional recovery group,
/// low-frequency utility actions, and quit. All secondary and utility
/// actions dismiss the panel after firing so focus shifts cleanly to Chrome
/// or to the next window; the primary launch action stays open so the user
/// can watch progress and the resulting status.
struct MenuBarView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s3) {
            panelHeader
            PrimaryAttendanceAction(status: state.status) {
                Task { await state.openAttendance() }
            }
            Divider()
            CommandRow(title: "창 앞으로 가져오기", systemImage: "macwindow.and.cursorarrow") {
                Task {
                    await state.bringForward()
                    dismiss()
                }
            }
            CommandRow(title: "페이지 새로고침", systemImage: "arrow.clockwise") {
                Task {
                    await state.reload()
                    dismiss()
                }
            }
            Divider()
            statusGroup
            if panelStatus.showsRecovery {
                Divider()
                recoveryGroup
            }
            Divider()
            CommandRow(title: "업데이트 확인…", systemImage: "arrow.up.circle") {
                state.updater.checkForUpdates()
                dismiss()
            }
            CommandRow(title: "설정…", systemImage: "gearshape") {
                openSettings()
                dismiss()
            }
            Divider()
            CommandRow(title: "SKALA Attendance 종료", systemImage: "power", role: .destructive) {
                quitApp()
            }
        }
        .padding(.vertical, DesignTokens.Spacing.s3)
        .padding(.horizontal, DesignTokens.Spacing.s4)
        .frame(
            minWidth: DesignTokens.Panel.minWidth,
            idealWidth: DesignTokens.Panel.idealWidth,
            maxWidth: DesignTokens.Panel.maxWidth,
            alignment: .topLeading
        )
        .confirmationDialog(
            "전용 브라우저 세션을 초기화할까요? 전용 Chrome 프로필만 삭제되며 다시 로그인해야 합니다.",
            isPresented: $confirmsReset
        ) {
            Button("초기화", role: .destructive) {
                Task {
                    await state.resetBrowserSession()
                    dismiss()
                }
            }
            Button("취소", role: .cancel) {}
        }
        .onAppear(perform: handleAppear)
    }

    private var panelHeader: some View {
        HStack(spacing: DesignTokens.Spacing.s2) {
            Image(systemName: "checkmark.rectangle")
                .symbolRenderingMode(.hierarchical)
                .font(.headline)
                .accessibilityHidden(true)
            Text(AppConstants.appName)
                .font(.headline.weight(.semibold))
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var panelStatus: PanelStatus {
        PanelStatus(status: state.status)
    }

    @ViewBuilder
    private var statusGroup: some View {
        VStack(spacing: DesignTokens.Spacing.s2) {
            StatusRow(
                tone: panelStatus.tone,
                label: "상태",
                value: panelStatus.headline
            )
        }
    }

    @ViewBuilder
    private var recoveryGroup: some View {
        VStack(spacing: DesignTokens.Spacing.s2) {
            CommandRow(title: "연결 진단…", systemImage: "stethoscope") {
                Task {
                    _ = await state.runConnectionDiagnostics()
                    openSettings()
                    dismiss()
                }
            }
            CommandRow(
                title: "브라우저 세션 초기화…",
                systemImage: "arrow.counterclockwise.circle",
                role: .destructive
            ) {
                confirmsReset = true
            }
            CommandRow(title: "문제 보고…", systemImage: "exclamationmark.bubble") {
                NSWorkspace.shared.open(AppConstants.repositoryURL.appendingPathComponent("issues"))
                dismiss()
            }
        }
    }

    private func handleAppear() {
        if state.preferences.onboardingCompleted,
           MenuBarController.opensAttendanceOnMenuActivation(preferences: state.preferences) {
            Task { await state.openAttendance() }
        } else if !state.preferences.onboardingCompleted {
            openWindow(id: "onboarding")
        }
    }

    private func quitApp() {
        Task {
            try? await state.persistCurrentWindowBounds()
            await state.chromeController.closeDedicatedChrome()
            NSApplication.shared.terminate(nil)
        }
    }
}
