import Foundation

extension AppState {
    @discardableResult
    func runConnectionDiagnostics() async -> String {
        let locator = ChromeLocator()
        let executable = try? locator.executableURL()
        let chromeVersion = executable.flatMap { ChromeVersionReader().readVersion(executableURL: $0)?.full }
        let endpoint = try? ChromeProfileManager(paths: paths).readDevToolsEndpoint()
        let portStatus: String
        if let endpoint {
            let baseURL = URL(string: "http://127.0.0.1:\(endpoint.port)")!
            let versionURL = baseURL.appendingPathComponent("json/version")
            var request = URLRequest(url: versionURL)
            request.timeoutInterval = 1.0
            let response = try? await URLSession.shared.data(for: request).1
            portStatus = (response as? HTTPURLResponse)?.statusCode == 200 ? "reachable" : "unreachable"
        } else {
            portStatus = "missing"
        }
        let diagnostics = ChromeDiagnostics(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            chromeInstalled: executable != nil,
            chromeVersion: chromeVersion,
            devToolsPortStatus: portStatus,
            errorCode: status.errorCode
        )

        let description = diagnostics.userSafeDescription
        connectionDiagnostics = description
        return description
    }
}
