import Foundation

enum ChromeLocatorError: LocalizedError, Equatable {
    case notFound
    case identityMismatch

    var errorDescription: String? {
        switch self {
        case .notFound:
            "Google Chrome이 필요합니다. 설치 후 다시 확인해 주세요."
        case .identityMismatch:
            "Google Chrome이 설치된 것으로 보이지만 번들 식별자가 일치하지 않습니다. 공식 Google Chrome을 설치해 주세요."
        }
    }
}

enum ChromeSessionError: LocalizedError, Equatable {
    case devToolsPortMissing
    case targetUnavailable

    var errorDescription: String? {
        switch self {
        case .devToolsPortMissing:
            "Chrome 디버깅 포트를 확인하지 못했습니다."
        case .targetUnavailable:
            "출결 브라우저 창을 준비하지 못했습니다."
        }
    }
}
