import Foundation

enum AppStatus: Equatable, Sendable {
    case chromeMissing
    case chromeStarting
    case cdpConnecting
    case openingAttendance
    case ready
    case connectionError(String)
    case profileResetRequired

    var displayText: String {
        switch self {
        case .chromeMissing:
            "Chrome 미설치"
        case .chromeStarting:
            "Chrome 시작 중"
        case .cdpConnecting:
            "CDP 연결 중"
        case .openingAttendance:
            "출결 페이지 여는 중"
        case .ready:
            "준비됨"
        case .connectionError:
            "연결 오류"
        case .profileResetRequired:
            "전용 프로필 초기화 필요"
        }
    }
}

extension AppStatus {
    var errorCode: String? {
        switch self {
        case .ready:
            nil
        case .chromeMissing:
            "chrome_missing"
        case .chromeStarting:
            "chrome_starting"
        case .cdpConnecting:
            "cdp_connecting"
        case .openingAttendance:
            "opening_attendance"
        case .connectionError:
            "connection_error"
        case .profileResetRequired:
            "profile_reset_required"
        }
    }
}
