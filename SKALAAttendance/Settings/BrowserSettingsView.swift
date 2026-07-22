import SwiftUI

/// 브라우저 settings tab (DESIGN.md §4 `SettingsSection`, `DestructiveAction`).
///
/// Preserves the existing status labels, Finder reveal, connection
/// diagnostics, destructive reset, and confirmation dialog. The destructive
/// `브라우저 세션 초기화` action stays in its own section, visually
/// separated from routine controls, with the existing native confirmation
/// dialog offering cancel as the safe default. Reset copy makes clear that
/// only the dedicated profile is removed and that the user must sign in
/// again.
struct BrowserSettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var confirmsReset = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Chrome", value: state.chromeDescription)
                LabeledContent("Chrome 버전", value: state.chromeVersionDescription)
                LabeledContent {
                    Text(state.paths.chromeProfile.path)
                        .font(.caption.monospaced())
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                } label: {
                    Text("전용 프로필")
                }
            } header: {
                Label("상태", systemImage: "info.circle")
            }

            Section {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([state.paths.chromeProfile])
                } label: {
                    Label("전용 프로필 위치를 Finder에서 보기", systemImage: "folder")
                }
                Button {
                    Task {
                        _ = await state.runConnectionDiagnostics()
                    }
                } label: {
                    Label("연결 진단", systemImage: "stethoscope")
                }
            } header: {
                Label("진단", systemImage: "waveform.path.ecg")
            }

            if let diagnosticsText = state.connectionDiagnostics {
                Section {
                    Text("연결 진단을 완료했습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(diagnosticsText)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Label("진단 결과", systemImage: "doc.text.magnifyingglass")
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmsReset = true
                } label: {
                    Label("브라우저 세션 초기화", systemImage: "arrow.counterclockwise.circle")
                }
            } header: {
                Label("초기화", systemImage: "exclamationmark.triangle")
            } footer: {
                Text("전용 Chrome 프로필만 삭제되며 일반 Chrome 프로필은 변경되지 않습니다. 다시 로그인해야 합니다.")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "전용 브라우저 세션을 초기화할까요? 다시 로그인해야 합니다.",
            isPresented: $confirmsReset
        ) {
            Button("초기화", role: .destructive) {
                Task { await state.resetBrowserSession() }
            }
            Button("취소", role: .cancel) {}
        }
    }
}
