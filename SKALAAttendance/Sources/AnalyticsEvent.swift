import Foundation

enum AnalyticsEvent: String, Sendable {
    case install
    case appLaunch = "app_launch"
    case attendanceOpen = "attendance_open"

    var path: String {
        switch self {
        case .install: "/app/install"
        case .appLaunch: "/app/launch"
        case .attendanceOpen: "/attendance/open"
        }
    }
}
