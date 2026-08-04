import Foundation
import WebKit
import XCTest
@testable import SKALA_Attendance

final class AnalyticsEventTests: XCTestCase {
    func testWebViewFailureClassifierUsesOnlyCoarseReasons() {
        XCTAssertEqual(
            WebViewLoadFailureReason.classify(URLError(.notConnectedToInternet)),
            .offline
        )
        XCTAssertEqual(
            WebViewLoadFailureReason.classify(URLError(.timedOut)),
            .timeout
        )
        XCTAssertEqual(
            WebViewLoadFailureReason.classify(URLError(.cannotFindHost)),
            .dns
        )
        XCTAssertEqual(
            WebViewLoadFailureReason.classify(URLError(.cannotConnectToHost)),
            .refused
        )
        XCTAssertEqual(
            WebViewLoadFailureReason.classify(URLError(.secureConnectionFailed)),
            .tls
        )
        XCTAssertEqual(
            WebViewLoadFailureReason.classify(URLError(.badURL)),
            .unknown
        )
    }

    func testWebViewFailureClassifierExcludesCancellation() {
        XCTAssertNil(WebViewLoadFailureReason.classify(URLError(.cancelled)))
    }

    func testAuthenticationProfileFillAllowsOnlyExactAuthOrigin() {
        XCTAssertTrue(isAuthenticationPageURL(URL(string: "https://auth.skala-ai.com/")))
        XCTAssertTrue(isAuthenticationPageURL(URL(string: "https://AUTH.SKALA-AI.COM/?source=app")))
        XCTAssertTrue(isAuthenticationPageURL(URL(string: "https://auth.skala-ai.com:443/verify")))

        XCTAssertFalse(isAuthenticationPageURL(nil))
        XCTAssertFalse(isAuthenticationPageURL(URL(string: "http://auth.skala-ai.com/")))
        XCTAssertFalse(isAuthenticationPageURL(URL(string: "https://auth.skala-ai.com:444/")))
        XCTAssertFalse(isAuthenticationPageURL(URL(string: "https://sub.auth.skala-ai.com/")))
        XCTAssertFalse(isAuthenticationPageURL(URL(string: "https://auth.skala-ai.com.evil.example/")))
    }

    @MainActor
    func testProvisionalNavigationFailureReportsCoarseReason() {
        var reasons: [WebViewLoadFailureReason] = []
        let delegate = WebViewNavigationDelegate { reasons.append($0) }
        let webView = WKWebView()

        delegate.webView(
            webView,
            didFailProvisionalNavigation: nil,
            withError: URLError(.notConnectedToInternet)
        )

        XCTAssertEqual(reasons, [.offline])
    }

    @MainActor
    func testCommittedNavigationFailureReportsCoarseReason() {
        var reasons: [WebViewLoadFailureReason] = []
        let delegate = WebViewNavigationDelegate { reasons.append($0) }
        let webView = WKWebView()

        delegate.webView(
            webView,
            didFail: nil,
            withError: URLError(.timedOut)
        )

        XCTAssertEqual(reasons, [.timeout])
    }

    @MainActor
    func testNavigationFailureCallbacksExcludeCancellation() {
        var reasons: [WebViewLoadFailureReason] = []
        let delegate = WebViewNavigationDelegate { reasons.append($0) }
        let webView = WKWebView()

        delegate.webView(webView, didFailProvisionalNavigation: nil, withError: URLError(.cancelled))
        delegate.webView(webView, didFail: nil, withError: URLError(.cancelled))

        XCTAssertTrue(reasons.isEmpty)
    }

    func testNewEventPaths() {
        XCTAssertEqual(AnalyticsEvent.webViewLoadFailed.rawValue, "webview_load_failed")
        XCTAssertEqual(AnalyticsEvent.webViewLoadFailed.path, "/webview/load-failed")
        XCTAssertEqual(AnalyticsEvent.activeInstallation.rawValue, "active_installation")
        XCTAssertEqual(AnalyticsEvent.activeInstallation.path, "/app/active")
        XCTAssertEqual(AnalyticsEvent.updateCheck.rawValue, "update_check")
        XCTAssertEqual(AnalyticsEvent.updateCheck.path, "/update/check")
        XCTAssertEqual(AnalyticsEvent.updateDownload.rawValue, "update_download")
        XCTAssertEqual(AnalyticsEvent.updateDownload.path, "/update/download")
        XCTAssertEqual(AnalyticsEvent.updateInstall.rawValue, "update_install")
        XCTAssertEqual(AnalyticsEvent.updateInstall.path, "/update/install")
    }

    func testFailureEventSerializesOnlySyntheticPathAndCoarseReason() async throws {
        let client = AnalyticsClient(
            configuration: AnalyticsConfiguration(
                baseURL: URL(string: "https://analytics.example")!,
                websiteID: "test-site",
                hostname: "attendance-app.skalife.kr"
            )
        )

        let payload = try XCTUnwrap(client.serializedPayload(
            for: .webViewLoadFailed,
            installationID: "test-install",
            sessionID: "test-session",
            extraData: ["reason": "offline"],
            websiteID: "test-site"
        ))

        let serializedPayload = try XCTUnwrap(String(data: payload, encoding: .utf8))
        XCTAssertTrue(serializedPayload.contains("\"reason\":\"offline\""))
        XCTAssertFalse(serializedPayload.contains("att.skala-ai.com"))
        XCTAssertFalse(serializedPayload.contains("https://"))
        XCTAssertFalse(serializedPayload.contains("Cookie"))
        XCTAssertFalse(serializedPayload.contains("token"))
        XCTAssertFalse(serializedPayload.contains("password"))
    }

    func testUpdateTelemetrySerializesOnlyCoarseResult() throws {
        let client = AnalyticsClient(
            configuration: AnalyticsConfiguration(
                baseURL: URL(string: "https://analytics.example")!,
                websiteID: "test-site",
                hostname: "attendance-app.skalife.kr"
            )
        )

        let payload = try XCTUnwrap(client.serializedPayload(
            for: .updateDownload,
            installationID: "test-install",
            sessionID: "test-session",
            extraData: ["result": "completed"],
            websiteID: "test-site"
        ))

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: payload) as? [String: Any]
        )
        let payloadObject = try XCTUnwrap(object["payload"] as? [String: Any])
        let data = try XCTUnwrap(payloadObject["data"] as? [String: Any])
        XCTAssertEqual(payloadObject["id"] as? String, "test-install")
        XCTAssertNil(payloadObject["distinctId"])
        XCTAssertEqual(data["analytics_schema"] as? String, "2")
        XCTAssertEqual(data["installation_id"] as? String, "test-install")
        XCTAssertEqual(data["session_id"] as? String, "test-session")
        XCTAssertNotEqual(payloadObject["id"] as? String, data["session_id"] as? String)

        XCTAssertEqual(data["result"] as? String, "completed")
        XCTAssertFalse(data.keys.contains("url"))
        XCTAssertFalse(data.keys.contains("version"))
        XCTAssertFalse(data.keys.contains("error"))
    }

    func testPrivacyDisclosureIncludesAllTelemetryAndExclusions() {
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("영구 저장되는 임의 설치 ID"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("종료 시 폐기되는 임의 세션 ID"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("설치·앱 실행·일일 활성 상태·출결 화면 열기"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("웹뷰 연결 실패"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("업데이트 확인·다운로드·설치 상태"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("분석 형식 버전"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("앱 버전과 빌드 번호, macOS 버전, arm64 아키텍처"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("계정 정보, 인증 설정, 출결 내역"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("실제 방문 주소, 페이지 내용, 쿠키, 토큰"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("Wi-Fi·유선 연결 여부, 하드웨어 식별자"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("IP 주소를 처리할 수 있습니다"))
        XCTAssertFalse(analyticsPrivacyDisclosure.localizedCaseInsensitiveContains("GitHub Star"))
    }

    func testUpdateTelemetrySuppressesAbortAfterNoUpdate() {
        var state = UpdateTelemetryState()

        state.didNotFindUpdate()

        XCTAssertFalse(state.didAbortUpdateCheck())
        XCTAssertTrue(state.didAbortUpdateCheck())
    }

    func testUpdateTelemetrySuppressesAbortAfterDownloadFailure() {
        var state = UpdateTelemetryState()

        state.didFailDownload()

        XCTAssertFalse(state.didAbortUpdateCheck())
        XCTAssertTrue(state.didAbortUpdateCheck())
    }

    func testUpdateTelemetrySuppressesAbortAfterFoundUpdate() {
        var state = UpdateTelemetryState()

        state.didFindUpdate()

        XCTAssertFalse(state.didAbortUpdateCheck())
    }
}

final class AnalyticsDeliveryTests: XCTestCase {
    override func tearDown() {
        AnalyticsURLProtocolStub.prepare([])
        super.tearDown()
    }

    func testOnlyHTTP2xxIsAccepted() {
        XCTAssertEqual(AnalyticsClient.deliveryResult(for: 200), .accepted)
        XCTAssertEqual(AnalyticsClient.deliveryResult(for: 204), .accepted)
        XCTAssertEqual(AnalyticsClient.deliveryResult(for: 299), .accepted)
        XCTAssertEqual(AnalyticsClient.deliveryResult(for: 300), .rejected(statusCode: 300))
        XCTAssertEqual(AnalyticsClient.deliveryResult(for: 400), .rejected(statusCode: 400))
        XCTAssertEqual(AnalyticsClient.deliveryResult(for: 408), .retryableFailure)
        XCTAssertEqual(AnalyticsClient.deliveryResult(for: 425), .retryableFailure)
        XCTAssertEqual(AnalyticsClient.deliveryResult(for: 429), .retryableFailure)
        XCTAssertEqual(AnalyticsClient.deliveryResult(for: 500), .retryableFailure)
        XCTAssertEqual(AnalyticsClient.deliveryResult(for: 599), .retryableFailure)
    }

    func testRetries429And5xxUntilAccepted() async {
        AnalyticsURLProtocolStub.prepare([.status(429), .status(503), .status(204)])
        let result = await makeClient(maximumAttempts: 3).track(
            .appLaunch,
            installationID: "test-install",
            analyticsEnabled: true,
            sessionID: "test-session"
        )

        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(AnalyticsURLProtocolStub.requestCount, 3)
    }

    func testRetriesNetworkFailureUntilAccepted() async {
        AnalyticsURLProtocolStub.prepare([.networkFailure, .status(200)])
        let result = await makeClient(maximumAttempts: 3).track(
            .appLaunch,
            installationID: "test-install",
            analyticsEnabled: true,
            sessionID: "test-session"
        )

        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(AnalyticsURLProtocolStub.requestCount, 2)
    }

    func testRetryCountIsBounded() async {
        AnalyticsURLProtocolStub.prepare([
            .status(500),
            .status(500),
            .status(500),
            .status(204),
        ])
        let result = await makeClient(maximumAttempts: 3).track(
            .appLaunch,
            installationID: "test-install",
            analyticsEnabled: true,
            sessionID: "test-session"
        )

        XCTAssertEqual(result, .retryableFailure)
        XCTAssertEqual(AnalyticsURLProtocolStub.requestCount, 3)
    }

    func testPermanentRejectionIsNotRetried() async {
        AnalyticsURLProtocolStub.prepare([.status(400), .status(204)])
        let result = await makeClient(maximumAttempts: 3).track(
            .appLaunch,
            installationID: "test-install",
            analyticsEnabled: true,
            sessionID: "test-session"
        )

        XCTAssertEqual(result, .rejected(statusCode: 400))
        XCTAssertEqual(AnalyticsURLProtocolStub.requestCount, 1)
    }

    func testLifecycleMarkersAdvanceOnlyAfterAcceptedDelivery() {
        let suiteName = "AnalyticsDeliveryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AnalyticsLifecycle.recordInstallDelivery(.retryableFailure, defaults: defaults)
        AnalyticsLifecycle.recordInstallDelivery(.rejected(statusCode: 400), defaults: defaults)
        XCTAssertFalse(defaults.bool(forKey: AnalyticsLifecycle.installEventSentKey))
        XCTAssertEqual(
            defaults.integer(forKey: AnalyticsLifecycle.installEventSchemaVersionKey),
            0
        )

        AnalyticsLifecycle.recordInstallDelivery(.accepted, defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: AnalyticsLifecycle.installEventSentKey))
        XCTAssertEqual(
            defaults.integer(forKey: AnalyticsLifecycle.installEventSchemaVersionKey),
            AnalyticsSchema.currentVersion
        )

        AnalyticsLifecycle.recordActiveInstallationDelivery(
            .retryableFailure,
            day: "2026-08-04",
            defaults: defaults
        )
        XCTAssertNil(defaults.string(forKey: AnalyticsLifecycle.activeInstallationDayKey))

        AnalyticsLifecycle.recordActiveInstallationDelivery(
            .accepted,
            day: "2026-08-04",
            defaults: defaults
        )
        XCTAssertEqual(
            defaults.string(forKey: AnalyticsLifecycle.activeInstallationDayKey),
            "2026-08-04"
        )
    }

    func testLegacyInstallMarkerDoesNotSuppressSchema2Migration() {
        let suiteName = "AnalyticsDeliveryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: AnalyticsLifecycle.installEventSentKey)
        XCTAssertTrue(AnalyticsLifecycle.shouldSendInstall(defaults: defaults))

        AnalyticsLifecycle.recordInstallDelivery(.accepted, defaults: defaults)
        XCTAssertFalse(AnalyticsLifecycle.shouldSendInstall(defaults: defaults))
    }

    func testExistingInstallationIDStorageKeyAndUTCDayRemainStable() {
        XCTAssertEqual(AnalyticsLifecycle.installationIDKey, "anonymousInstallID")
        XCTAssertEqual(
            AnalyticsLifecycle.utcDay(containing: Date(timeIntervalSince1970: 0)),
            "1970-01-01"
        )
    }

    private func makeClient(maximumAttempts: Int) -> AnalyticsClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AnalyticsURLProtocolStub.self]
        return AnalyticsClient(
            configuration: AnalyticsConfiguration(
                baseURL: URL(string: "https://analytics.example")!,
                websiteID: "test-site",
                hostname: "attendance-app.skalife.kr"
            ),
            session: URLSession(configuration: configuration),
            retryPolicy: AnalyticsRetryPolicy(
                maximumAttempts: maximumAttempts,
                initialDelayNanoseconds: 0
            )
        )
    }
}

private final class AnalyticsURLProtocolStub: URLProtocol, @unchecked Sendable {
    enum Outcome {
        case status(Int)
        case networkFailure
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var outcomes: [Outcome] = []
    nonisolated(unsafe) private(set) static var requestCount = 0

    static func prepare(_ newOutcomes: [Outcome]) {
        lock.lock()
        outcomes = newOutcomes
        requestCount = 0
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let outcome = Self.nextOutcome()
        switch outcome {
        case let .status(statusCode):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        case .networkFailure:
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        }
    }

    override func stopLoading() {}

    private static func nextOutcome() -> Outcome {
        lock.lock()
        defer { lock.unlock() }
        requestCount += 1
        return outcomes.isEmpty ? .networkFailure : outcomes.removeFirst()
    }
}
