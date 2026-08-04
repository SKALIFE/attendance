import Foundation

enum AnalyticsEvent: String, Sendable {
    case install
    case appLaunch = "app_launch"
    case activeInstallation = "active_installation"
    case attendanceOpen = "attendance_open"
    case webViewLoadFailed = "webview_load_failed"
    case updateCheck = "update_check"
    case updateDownload = "update_download"
    case updateInstall = "update_install"

    var path: String {
        switch self {
        case .install: "/app/install"
        case .appLaunch: "/app/launch"
        case .activeInstallation: "/app/active"
        case .attendanceOpen: "/attendance/open"
        case .webViewLoadFailed: "/webview/load-failed"
        case .updateCheck: "/update/check"
        case .updateDownload: "/update/download"
        case .updateInstall: "/update/install"
        }
    }
}
