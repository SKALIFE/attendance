import SwiftUI

@main
struct SKALAAttendanceApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra(AppConstants.appName, systemImage: "checkmark.rectangle") {
            MenuBarView()
                .environmentObject(state)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(state)
        }

        Window("SKALA Attendance 시작", id: "onboarding") {
            OnboardingView()
                .environmentObject(state)
        }
        .defaultLaunchBehavior(.presented)
    }
}
