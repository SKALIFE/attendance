import Foundation

struct ChromeDiagnostics: Equatable, Sendable {
    let appVersion: String
    let macOSVersion: String
    let chromeInstalled: Bool
    let chromeVersion: String?
    let devToolsPortStatus: String
    let errorCode: String?

    var userSafeDescription: String {
        [
            "app_version=\(appVersion)",
            "macos_version=\(macOSVersion)",
            "chrome_installed=\(chromeInstalled)",
            chromeVersion.map { "chrome_version=\($0)" },
            "devtools_port=\(devToolsPortStatus)",
            errorCode.map { "error_code=\($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}
