import SwiftUI

/// Native tabbed settings window (DESIGN.md §3).
///
/// Keeps the existing 560 by 420 pt baseline and the tab order
/// 일반 → 개인정보 → 브라우저 → 업데이트 → 정보. Each tab carries a
/// symbol-led label so the tab bar stays scannable.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("일반", systemImage: "gearshape") }
            PrivacySettingsView()
                .tabItem { Label("개인정보", systemImage: "lock.shield") }
            BrowserSettingsView()
                .tabItem { Label("브라우저", systemImage: "macwindow") }
            UpdatesSettingsView()
                .tabItem { Label("업데이트", systemImage: "arrow.up.circle") }
            AboutSettingsView()
                .tabItem { Label("정보", systemImage: "info.circle") }
        }
        .frame(
            width: DesignTokens.SettingsLayout.width,
            height: DesignTokens.SettingsLayout.height
        )
    }
}
