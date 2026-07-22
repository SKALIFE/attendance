import XCTest
@testable import SKALAAttendance

final class ChromeTests: XCTestCase {
    func testChromeVersion_whenParsingGoogleOutput_extractsMajorAndFullVersion() {
        let version = ChromeVersion.parse("Google Chrome 150.0.7871.125")

        XCTAssertEqual(version, ChromeVersion(major: 150, full: "150.0.7871.125"))
    }

    func testLaunchArguments_whenBuilt_useDedicatedProfileAndAboutBlankAppMode() {
        let config = ChromeLaunchConfiguration(
            executableURL: URL(fileURLWithPath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
            profileURL: URL(fileURLWithPath: "/tmp/app/ChromeProfile"),
            remoteDebuggingPort: nil,
            windowBounds: WindowBounds(x: 0, y: 0, width: 430, height: 900)
        )

        XCTAssertTrue(config.arguments.contains("--user-data-dir=/tmp/app/ChromeProfile"))
        XCTAssertTrue(config.arguments.contains("--remote-debugging-address=127.0.0.1"))
        XCTAssertTrue(config.arguments.contains("--remote-debugging-port=0"))
        XCTAssertTrue(config.arguments.contains("--app=about:blank"))
        XCTAssertFalse(config.arguments.contains { $0.contains("att.skala-ai.com") })
    }

    func testDiagnostics_whenRendered_excludesSensitiveProfileData() {
        let diagnostics = ChromeDiagnostics(
            appVersion: "1.0.0",
            macOSVersion: "26.0",
            chromeInstalled: true,
            chromeVersion: "150",
            devToolsPortStatus: "present",
            errorCode: "cdp_timeout"
        )

        XCTAssertFalse(diagnostics.userSafeDescription.contains("Cookie"))
        XCTAssertFalse(diagnostics.userSafeDescription.contains("ChromeProfile"))
        XCTAssertTrue(diagnostics.userSafeDescription.contains("chrome_installed=true"))
        XCTAssertTrue(diagnostics.userSafeDescription.contains("devtools_port=present"))
        XCTAssertTrue(diagnostics.userSafeDescription.contains("error_code=cdp_timeout"))
    }

    func testMenuBarController_whenOpenOnMenuClickEnabled_opensOnActivation() {
        var preferences = AppPreferences.defaults

        XCTAssertFalse(MenuBarController.opensAttendanceOnMenuActivation(preferences: preferences))

        preferences.openOnMenuClick = true

        XCTAssertTrue(MenuBarController.opensAttendanceOnMenuActivation(preferences: preferences))
    }

    func testChromeSessionController_whenNoCDPSession_rejectsWindowCommands() async {
        let controller = ChromeSessionController(paths: ApplicationSupportPaths(homeDirectory: URL(fileURLWithPath: "/tmp/skala-home")))

        do {
            try await controller.bringToFront()
            XCTFail("Expected bringToFront to throw when CDP is not connected")
        } catch let error as CDPClientError {
            XCTAssertEqual(error, .notConnected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            try await controller.reload()
            XCTFail("Expected reload to throw when CDP is not connected")
        } catch let error as CDPClientError {
            XCTAssertEqual(error, .notConnected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testChromeProfileManager_whenReadingDevToolsActivePort_keepsBrowserWebSocketPath() throws {
        let tempHome = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = ApplicationSupportPaths(homeDirectory: tempHome)
        let manager = ChromeProfileManager(paths: paths)
        try manager.prepareProfile()
        try "12345\n/devtools/browser/browser-id\n".write(to: manager.devToolsPortFile(), atomically: true, encoding: .utf8)

        let endpoint = try manager.readDevToolsEndpoint()

        XCTAssertEqual(endpoint, DevToolsEndpoint(port: 12345, browserPath: "/devtools/browser/browser-id"))
    }

    func testChromeSessionController_whenCheckingWebSocketURL_requiresLoopbackAndMatchingPort() {
        XCTAssertTrue(ChromeSessionController.isLoopbackWebSocket(URL(string: "ws://127.0.0.1:12345/devtools/page/1")!, matchingPort: 12345))
        XCTAssertTrue(ChromeSessionController.isLoopbackWebSocket(URL(string: "ws://localhost:12345/devtools/page/1")!, matchingPort: 12345))
        XCTAssertFalse(ChromeSessionController.isLoopbackWebSocket(URL(string: "ws://192.168.0.2:12345/devtools/page/1")!, matchingPort: 12345))
        XCTAssertFalse(ChromeSessionController.isLoopbackWebSocket(URL(string: "ws://127.0.0.1:54321/devtools/page/1")!, matchingPort: 12345))
        XCTAssertFalse(ChromeSessionController.isLoopbackWebSocket(URL(string: "http://127.0.0.1:12345/devtools/page/1")!, matchingPort: 12345))
    }

    func testChromeSessionController_whenIntegrationIsOptedIn_opensAttendancePageWithTemporaryProfile() async throws {
        try XCTSkipUnless(
            isChromeIntegrationEnabled,
            "Set SKALA_RUN_CHROME_INTEGRATION_TEST=1 to run the real Chrome integration test."
        )
        guard (try? ChromeLocator().executableURL()) != nil else {
            throw XCTSkip("Google Chrome is not installed.")
        }

        let temporaryHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("SKALAAttendance-ChromeIntegration-\(UUID().uuidString)", isDirectory: true)
        let paths = ApplicationSupportPaths(homeDirectory: temporaryHome)
        let controller = ChromeSessionController(paths: paths)
        defer {
            do {
                try SafeFileManager(paths: paths).removeChromeProfile()
                if FileManager.default.fileExists(atPath: temporaryHome.path) {
                    try FileManager.default.removeItem(at: temporaryHome)
                }
            } catch {
                XCTFail("Failed to remove temporary Chrome profile: \(error)")
            }
        }

        let bounds: WindowBounds
        do {
            bounds = try await controller.openAttendancePage(
                bounds: WindowBounds(x: 40, y: 40, width: 430, height: 900)
            )
        } catch {
            _ = await controller.closeDedicatedChrome()
            throw error
        }

        let closed = await controller.closeDedicatedChrome()
        XCTAssertTrue(closed, "Temporary dedicated Chrome must exit before profile cleanup.")
        XCTAssertTrue((360...600).contains(bounds.width))
        XCTAssertTrue((640...1_200).contains(bounds.height))
    }

    func testChromeLocator_whenBundleIdentifierMatches_acceptsChrome() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let chromeApp = tempDir.appendingPathComponent("Google Chrome.app")
        let contentsDir = chromeApp.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)
        try writeFakeInfoPlist(at: contentsDir.appendingPathComponent("Info.plist"), bundleIdentifier: ChromeLocator.expectedBundleIdentifier)

        let locator = ChromeLocator(customApps: [chromeApp])
        let found = try locator.findChromeApp()
        XCTAssertEqual(found, chromeApp)

        try FileManager.default.removeItem(at: tempDir)
    }

    func testChromeLocator_whenBundleIdentifierMismatch_rejectsImposter() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fakeChromeApp = tempDir.appendingPathComponent("Google Chrome.app")
        let contentsDir = fakeChromeApp.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)
        try writeFakeInfoPlist(at: contentsDir.appendingPathComponent("Info.plist"), bundleIdentifier: "com.evil.imposter")

        let locator = ChromeLocator(customApps: [fakeChromeApp])

        do {
            _ = try locator.findChromeApp()
            XCTFail("Expected identityMismatch for fake Chrome")
        } catch let error as ChromeLocatorError {
            XCTAssertEqual(error, .identityMismatch)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        try FileManager.default.removeItem(at: tempDir)
    }

    private func writeFakeInfoPlist(at url: URL, bundleIdentifier: String) throws {
        let plist: [String: Any] = ["CFBundleIdentifier": bundleIdentifier]
        try (plist as NSDictionary).write(to: url)
    }

    private var isChromeIntegrationEnabled: Bool {
        #if SKALA_CHROME_INTEGRATION_ENABLED
        true
        #else
        false
        #endif
    }
}
