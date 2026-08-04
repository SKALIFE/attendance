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
            distinctID: "test-install",
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
            distinctID: "test-install",
            extraData: ["result": "completed"],
            websiteID: "test-site"
        ))

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: payload) as? [String: Any]
        )
        let payloadObject = try XCTUnwrap(object["payload"] as? [String: Any])
        let data = try XCTUnwrap(payloadObject["data"] as? [String: Any])

        XCTAssertEqual(data["result"] as? String, "completed")
        XCTAssertFalse(data.keys.contains("url"))
        XCTAssertFalse(data.keys.contains("version"))
        XCTAssertFalse(data.keys.contains("error"))
    }

    func testPrivacyDisclosureIncludesAllTelemetryAndExclusions() {
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("영구 저장되는 익명 설치 ID"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("설치·앱 실행·출결 화면 열기"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("웹뷰 연결 실패"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("업데이트 확인·다운로드·설치 상태"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("앱 버전과 빌드 번호, macOS 버전, arm64 아키텍처"))
        XCTAssertTrue(analyticsPrivacyDisclosure.contains("계정 정보, 출결 내역, 실제 방문 주소, 페이지 내용, 쿠키, 토큰"))
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
