import Foundation

@MainActor
struct MenuBarController {
    let state: AppState

    func openAttendance() {
        Task { await state.openAttendance() }
    }

    nonisolated static func opensAttendanceOnMenuActivation(preferences: AppPreferences) -> Bool {
        preferences.openOnMenuClick
    }
}
