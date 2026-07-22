import Foundation

struct StatusText: Equatable, Sendable {
    let status: AppStatus

    var userMessage: String {
        switch status {
        case .connectionError:
            "출결 브라우저를 시작하지 못했습니다. Chrome이 업데이트 중이거나 전용 프로필이 다른 프로세스에서 사용 중일 수 있습니다."
        case .chromeMissing:
            "Google Chrome이 필요합니다. 이 앱은 Google 로그인과 패스키를 안전하게 사용하기 위해 설치된 Google Chrome을 사용합니다."
        default:
            status.displayText
        }
    }
}
