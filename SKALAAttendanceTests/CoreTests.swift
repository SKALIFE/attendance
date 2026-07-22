import XCTest
@testable import SKALAAttendance

final class CoreTests: XCTestCase {
    func testApplicationSupportPaths_whenCreated_useDedicatedBundleRoot() {
        let home = URL(fileURLWithPath: "/tmp/skala-home", isDirectory: true)
        let paths = ApplicationSupportPaths(homeDirectory: home)

        XCTAssertEqual(paths.root.path, "/tmp/skala-home/Library/Application Support/kr.skalife.attendance")
        XCTAssertEqual(paths.chromeProfile.lastPathComponent, "ChromeProfile")
        XCTAssertTrue(paths.isAppOwned(paths.chromeProfile))
        XCTAssertFalse(paths.isAppOwned(home.appendingPathComponent("Library/Application Support/Google/Chrome")))
    }

    func testWindowBounds_whenOutsideScreen_clampsIntoScreen() {
        let bounds = WindowBounds(x: -500, y: -400, width: 1200, height: 1200)

        let clamped = bounds.clamped(to: CGRect(x: 0, y: 0, width: 800, height: 1000))

        XCTAssertEqual(clamped.x, 0)
        XCTAssertEqual(clamped.y, 0)
        XCTAssertEqual(clamped.width, 800)
        XCTAssertEqual(clamped.height, 1000)
    }

    func testStatusText_whenChromeMissing_explainsChromeRequirement() {
        let text = StatusText(status: .chromeMissing).userMessage

        XCTAssertTrue(text.contains("Google Chrome이 필요합니다"))
        XCTAssertTrue(text.contains("패스키"))
    }

    func testStatusText_whenConnectionError_explainsLikelyRecovery() {
        let text = StatusText(status: .connectionError("low-level error")).userMessage

        XCTAssertTrue(text.contains("출결 브라우저를 시작하지 못했습니다"))
        XCTAssertFalse(text.contains("low-level error"))
    }

    @MainActor
    func testAppState_whenOpeningAttendance_usesSavedWindowBounds() {
        let paths = ApplicationSupportPaths(homeDirectory: FileManager.default.temporaryDirectory)
        let state = AppState(paths: paths)
        let savedBounds = WindowBounds(x: 1_000, y: 80, width: 440, height: 860)
        state.preferences.windowBounds = savedBounds

        XCTAssertEqual(state.attendanceLaunchBounds, savedBounds)
    }

    @MainActor
    func testAppState_whenRunningDiagnostics_keepsReadyStatus() async {
        let paths = ApplicationSupportPaths(homeDirectory: FileManager.default.temporaryDirectory)
        let state = AppState(paths: paths)
        state.status = .ready

        let diagnostics = await state.runConnectionDiagnostics()

        XCTAssertEqual(state.status, .ready)
        XCTAssertEqual(state.connectionDiagnostics, diagnostics)
    }

    @MainActor
    func testAppState_whenCancellingOnboardingReplay_keepsCompletionPersisted() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = ApplicationSupportPaths(homeDirectory: home)
        let state = AppState(paths: paths)
        state.preferences.onboardingCompleted = true
        state.savePreferences()

        state.beginOnboardingReplay()
        XCTAssertTrue(state.onboardingShouldBePresented)

        state.cancelOnboardingReplay()

        XCTAssertTrue(state.preferences.onboardingCompleted)
        XCTAssertFalse(state.onboardingShouldBePresented)
        XCTAssertTrue(try JSONPreferencesStore(fileURL: paths.preferencesFile).load().onboardingCompleted)
    }
}
