import Foundation

actor ChromeSessionController {
    private let paths: ApplicationSupportPaths
    private let locator: ChromeLocator
    private let profileManager: ChromeProfileManager
    private let processLauncher: ChromeProcess
    private let versionReader = ChromeVersionReader()
    private var cdpClient: CDPClient?
    private var process: Process?

    init(paths: ApplicationSupportPaths) {
        self.paths = paths
        locator = ChromeLocator()
        profileManager = ChromeProfileManager(paths: paths)
        processLauncher = ChromeProcess()
    }

    @discardableResult
    func openAttendancePage(bounds: WindowBounds) async throws -> WindowBounds {
        try profileManager.prepareProfile()
        let executable = try locator.executableURL()
        let chromeVersion = versionReader.readVersion(executableURL: executable) ?? ChromeVersion(major: 120, full: "120.0.0.0")
        let config = ChromeLaunchConfiguration(
            executableURL: executable,
            profileURL: paths.chromeProfile,
            remoteDebuggingPort: nil,
            windowBounds: bounds
        )
        if process == nil || process?.isRunning == false, try await existingDevToolsEndpoint() == nil {
            process = try processLauncher.launch(configuration: config)
        }
        let endpoint = try await waitForDevToolsEndpoint()
        if let existingClient = cdpClient {
            await existingClient.close()
            cdpClient = nil
        }
        let client = CDPClient(baseURL: endpoint.baseURL)
        let target = try await discoverOrCreatePageTarget(endpoint: endpoint)
        guard let webSocketURL = target.webSocketDebuggerURL else {
            throw ChromeSessionError.targetUnavailable
        }
        guard Self.isLoopbackWebSocket(webSocketURL, matchingPort: endpoint.port) else {
            throw ChromeSessionError.targetUnavailable
        }
        await client.connect(to: webSocketURL)
        await client.subscribeToEvents { [weak self] event in
            if event.method == "Target.targetDestroyed" || event.method == "Inspector.detached" {
                Task { [weak self] in
                    await self?.handleTargetLost()
                }
            }
        }
        do {
            _ = try await client.send(.targetSetDiscoverTargets)
        } catch {
            guard case CDPClientError.commandFailed = error else {
                throw error
            }
        }
        cdpClient = client
        let appliedBounds = try await CDPWindowController(client: client).setBounds(bounds)
        let navigator = CDPNavigationController(client: client)
        try await navigator.openAttendance(version: chromeVersion)
        return appliedBounds
    }

    func bringToFront() async throws {
        guard let cdpClient else {
            throw CDPClientError.notConnected
        }
        try await cdpClient.send(.pageBringToFront)
    }

    func currentWindowBounds() async throws -> WindowBounds {
        guard let cdpClient else {
            throw CDPClientError.notConnected
        }
        return try await CDPWindowController(client: cdpClient).currentBounds()
    }

    func reload() async throws {
        guard let cdpClient else {
            throw CDPClientError.notConnected
        }
        try await cdpClient.send(.pageReload)
    }

    @discardableResult
    func closeDedicatedChrome() async -> Bool {
        let client = cdpClient
        _ = try? await client?.send(.browserClose)
        await client?.close()

        var exited = true
        if let p = process, p.isRunning {
            p.terminate()
            for _ in 0..<50 {
                if !p.isRunning { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            exited = !p.isRunning
        }

        if cdpClient == nil && process == nil {
            if let endpoint = try? await existingDevToolsEndpoint(), let browserWS = endpoint.browserWebSocketURL {
                let tempClient = CDPClient(baseURL: endpoint.baseURL)
                await tempClient.connect(to: browserWS)
                _ = try? await tempClient.send(.browserClose)
                await tempClient.close()
            }
        }

        for _ in 0..<30 {
            if (try? await existingDevToolsEndpoint()) == nil { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        let endpointStillExists = (try? await existingDevToolsEndpoint()) != nil
        exited = exited && !endpointStillExists

        process = nil
        cdpClient = nil
        return exited
    }

    private func handleTargetLost() async {
        cdpClient = nil
    }

    private func discoverOrCreatePageTarget(endpoint: ValidatedDevToolsEndpoint) async throws -> CDPTarget {
        if let page = try await discoverPageTarget(endpoint: endpoint) {
            return page
        }
        if let page = try? await createPageTargetViaHTTP(endpoint: endpoint) {
            return page
        }

        guard let browserWebSocketURL = endpoint.browserWebSocketURL else {
            throw ChromeSessionError.targetUnavailable
        }
        let browserClient = CDPClient(baseURL: endpoint.baseURL)
        await browserClient.connect(to: browserWebSocketURL)
        _ = try await browserClient.send(.createTarget(url: URL(string: "about:blank")!))
        await browserClient.close()
        guard let page = try await discoverPageTarget(endpoint: endpoint) else {
            throw ChromeSessionError.targetUnavailable
        }
        return page
    }

    private func createPageTargetViaHTTP(endpoint: ValidatedDevToolsEndpoint) async throws -> CDPTarget? {
        guard let newURL = URL(string: "http://127.0.0.1:\(endpoint.port)/json/new?about:blank") else {
            return nil
        }
        var request = URLRequest(url: newURL)
        request.httpMethod = "PUT"
        request.timeoutInterval = 3.0
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let target = try JSONDecoder().decode(CDPTarget.self, from: data)
        guard target.type == "page",
              let webSocketURL = target.webSocketDebuggerURL,
              Self.isLoopbackWebSocket(webSocketURL, matchingPort: endpoint.port) else {
            return nil
        }
        return target
    }

    private func discoverPageTarget(endpoint: ValidatedDevToolsEndpoint) async throws -> CDPTarget? {
        let listURL = endpoint.baseURL.appendingPathComponent("json/list")
        let (data, _) = try await URLSession.shared.data(from: listURL)
        let targets = try JSONDecoder().decode([CDPTarget].self, from: data)
        return targets.first { target in
            guard target.type == "page", let webSocketURL = target.webSocketDebuggerURL else {
                return false
            }
            return Self.isLoopbackWebSocket(webSocketURL, matchingPort: endpoint.port)
        }
    }

    private func existingDevToolsEndpoint() async throws -> ValidatedDevToolsEndpoint? {
        guard let endpoint = try? profileManager.readDevToolsEndpoint() else {
            return nil
        }
        return await validateDevToolsEndpoint(endpoint)
    }

    private func validateDevToolsEndpoint(_ endpoint: DevToolsEndpoint) async -> ValidatedDevToolsEndpoint? {
        let baseURL = URL(string: "http://127.0.0.1:\(endpoint.port)")!
        let versionURL = baseURL.appendingPathComponent("json/version")
        var request = URLRequest(url: versionURL)
        request.timeoutInterval = 0.5
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let version = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let browserWebSocketValue = version["webSocketDebuggerUrl"] as? String,
                  let browserWebSocketURL = URL(string: browserWebSocketValue),
                  Self.isLoopbackWebSocket(browserWebSocketURL, matchingPort: endpoint.port),
                  endpoint.browserPath == nil || browserWebSocketURL.path == endpoint.browserPath else {
                return nil
            }
            return ValidatedDevToolsEndpoint(
                port: endpoint.port,
                baseURL: baseURL,
                browserWebSocketURL: browserWebSocketURL
            )
        } catch {
            return nil
        }
    }

    private func waitForDevToolsEndpoint() async throws -> ValidatedDevToolsEndpoint {
        for _ in 0..<80 {
            if let endpoint = try await existingDevToolsEndpoint() {
                return endpoint
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw ChromeSessionError.devToolsPortMissing
    }

    static func isLoopbackWebSocket(_ url: URL, matchingPort port: Int) -> Bool {
        guard url.scheme == "ws" || url.scheme == "wss",
              url.port == port,
              let host = url.host(percentEncoded: false) else {
            return false
        }
        return host == "127.0.0.1" || host == "localhost" || host == "::1" || host == "[::1]"
    }
}

struct ValidatedDevToolsEndpoint: Equatable, Sendable {
    let port: Int
    let baseURL: URL
    let browserWebSocketURL: URL?
}
