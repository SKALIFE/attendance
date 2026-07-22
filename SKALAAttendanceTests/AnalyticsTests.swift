import XCTest
@testable import SKALAAttendance

final class AnalyticsTests: XCTestCase {
    func testPreferencesDefaults_whenCreated_enableAnalyticsByDefaultForOnboarding() {
        XCTAssertTrue(AppPreferences.defaults.analyticsEnabled)
    }

    @MainActor
    func testPrivacyConsentViewDisclosure_whenShown_listsCollectedAndExcludedAnalyticsData() {
        let disclosure = PrivacyConsentView.disclosureLines.joined(separator: "\n")

        XCTAssertTrue(disclosure.contains("앱 개선을 위해 다음 정보만 전송합니다."))
        XCTAssertTrue(disclosure.contains("익명 설치 식별자"))
        XCTAssertTrue(disclosure.contains("앱 실행"))
        XCTAssertTrue(disclosure.contains("출결 페이지 열기"))
        XCTAssertTrue(disclosure.contains("앱 버전과 macOS 버전"))
        XCTAssertTrue(disclosure.contains("Google 계정, 이름, 이메일, 출결 기록"))
        XCTAssertTrue(disclosure.contains("방문한 페이지 내용과 Chrome 데이터는 수집하지 않습니다."))
        XCTAssertTrue(disclosure.contains("설정에서 언제든 끌 수 있습니다."))
    }

    func testPayload_whenUnconfigured_returnsNil() {
        let client = AnalyticsClient(
            configuration: AnalyticsConfiguration(baseURL: nil, websiteID: nil, hostname: "attendance-app.skalife.kr"),
            preferences: .defaults
        )

        XCTAssertNil(client.payload(for: .appLaunch, preferences: .defaults))
    }

    func testPayload_whenOptedOut_returnsNil() {
        var preferences = AppPreferences.defaults
        preferences.analyticsEnabled = false
        preferences.anonymousInstallID = "00000000-0000-0000-0000-000000000000"
        let client = configuredClient(preferences: preferences)

        XCTAssertNil(client.payload(for: .attendanceOpen, preferences: preferences))
    }

    func testPayload_whenEnabled_containsMinimalAnonymousDataOnly() throws {
        var preferences = AppPreferences.defaults
        preferences.analyticsEnabled = true
        preferences.anonymousInstallID = "00000000-0000-0000-0000-000000000000"
        let client = configuredClient(preferences: preferences)

        let payload = try XCTUnwrap(client.payload(for: .attendanceOpen, preferences: preferences))

        XCTAssertEqual(payload.website, "site-id")
        XCTAssertEqual(payload.url, "/attendance/open")
        XCTAssertEqual(payload.distinctID, "00000000-0000-0000-0000-000000000000")
        let serialized = String(data: try JSONSerialization.data(withJSONObject: payload.jsonObject()), encoding: .utf8) ?? ""
        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("email"))
        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("cookie"))
        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("token"))
        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("attendance_result"))
    }

    func testPayload_whenInstallEventConfigured_generatesValidInstallPayload() throws {
        var preferences = AppPreferences.defaults
        preferences.analyticsEnabled = true
        preferences.anonymousInstallID = "00000000-0000-0000-0000-000000000000"
        let client = configuredClient(preferences: preferences)

        let payload = try XCTUnwrap(client.payload(for: .install, preferences: preferences))

        XCTAssertEqual(payload.name, "install")
        XCTAssertEqual(payload.url, "/app/install")
        XCTAssertEqual(payload.distinctID, "00000000-0000-0000-0000-000000000000")
    }

    @MainActor
    func testAppState_whenAnalyticsEnabledDuringOnboarding_waitsForCompletionBeforeSending() async throws {
        let paths = ApplicationSupportPaths(homeDirectory: temporaryHome())
        let state = AppState(paths: paths)

        await state.setAnalyticsEnabled(true)

        XCTAssertTrue(state.preferences.analyticsEnabled)
        XCTAssertNil(state.preferences.anonymousInstallID)
        XCTAssertFalse(state.preferences.installEventSent)
    }

    @MainActor
    func testAppState_whenUnconfiguredAnalyticsCompletesOnboarding_doesNotMarkInstallSent() async throws {
        let paths = ApplicationSupportPaths(homeDirectory: temporaryHome())
        let state = AppState(paths: paths)

        await state.completeOnboarding()

        XCTAssertTrue(state.preferences.onboardingCompleted)
        XCTAssertNotNil(state.preferences.anonymousInstallID)
        XCTAssertFalse(state.preferences.installEventSent)
    }

    @MainActor
    func testAppState_whenConfiguredAnalyticsCompletesOnboarding_marksInstallSentOnce() async throws {
        let paths = ApplicationSupportPaths(homeDirectory: temporaryHome())
        let config = AnalyticsConfiguration(baseURL: URL(string: "https://analytics.example.test"), websiteID: "site-id", hostname: "test")
        let state = AppState(paths: paths, analyticsConfiguration: config)

        await state.completeOnboarding()

        XCTAssertTrue(state.preferences.installEventSent)
    }

    @MainActor
    func testAppState_whenConfiguredAnalyticsReEnabled_doesNotDuplicateAppLaunch() async throws {
        let paths = ApplicationSupportPaths(homeDirectory: temporaryHome())
        let config = AnalyticsConfiguration(baseURL: URL(string: "https://analytics.example.test"), websiteID: "site-id", hostname: "test")
        let state = AppState(paths: paths, analyticsConfiguration: config)

        await state.completeOnboarding()
        let firstLaunchID = state.preferences.anonymousInstallID
        XCTAssertTrue(state.appLaunchTracked)

        await state.setAnalyticsEnabled(false)
        await state.setAnalyticsEnabled(true)

        XCTAssertEqual(state.preferences.anonymousInstallID, firstLaunchID)
        XCTAssertTrue(state.preferences.installEventSent)
        XCTAssertTrue(state.appLaunchTracked)
    }

    @MainActor
    func testAnonymousInstallID_whenGenerated_producesUniqueValues() {
        let id1 = AnonymousInstallID.generate().value
        let id2 = AnonymousInstallID.generate().value

        XCTAssertNotNil(id1)
        XCTAssertNotNil(id2)
        XCTAssertNotEqual(id1, id2)
    }

    @MainActor
    func testAnonymousInstallID_whenReset_generatesNewValue() {
        let original = AnonymousInstallID.generate().value
        let reset = AnonymousInstallID.generate().value

        XCTAssertNotEqual(original, reset)
        XCTAssertTrue(reset.count > 0)
    }

    private func configuredClient(preferences: AppPreferences) -> AnalyticsClient {
        AnalyticsClient(
            configuration: AnalyticsConfiguration(baseURL: URL(string: "https://analytics.example.test"), websiteID: "site-id", hostname: "attendance-app.skalife.kr"),
            preferences: preferences
        )
    }

    private func temporaryHome() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
