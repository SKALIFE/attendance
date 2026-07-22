import XCTest
@testable import SKALAAttendance

/// Focused tests for the only new pure logic introduced by the native shell
/// redesign: `PanelStatus`. View-layer changes are exercised by build and
/// manual QA; these tests pin the tone, symbol, headline, recovery, and
/// launch-gating mapping so future refactors do not silently change panel
/// behavior.
final class PanelStatusTests: XCTestCase {
    func testReady_toneAndSymbol_areReady() {
        let panel = PanelStatus(status: .ready)

        XCTAssertEqual(panel.tone, .ready)
        XCTAssertEqual(panel.symbolName, "checkmark.circle")
        XCTAssertEqual(panel.headline, "준비됨")
        XCTAssertFalse(panel.showsRecovery)
        XCTAssertFalse(panel.isLaunching)
    }

    func testChromeStarting_toneIsTransitional_andIsLaunching() {
        let panel = PanelStatus.emptyReplacingStatus(.chromeStarting)

        XCTAssertEqual(panel.tone, .transitional)
        XCTAssertTrue(panel.isLaunching)
        XCTAssertFalse(panel.showsRecovery)
    }

    func testCdpConnecting_toneIsTransitional_andIsLaunching() {
        let panel = PanelStatus.emptyReplacingStatus(.cdpConnecting)

        XCTAssertEqual(panel.tone, .transitional)
        XCTAssertTrue(panel.isLaunching)
    }

    func testOpeningAttendance_toneIsTransitional_andIsLaunching() {
        let panel = PanelStatus.emptyReplacingStatus(.openingAttendance)

        XCTAssertEqual(panel.tone, .transitional)
        XCTAssertTrue(panel.isLaunching)
    }

    func testChromeMissing_toneIsCaution_andNotRecovery() {
        let panel = PanelStatus.emptyReplacingStatus(.chromeMissing)

        XCTAssertEqual(panel.tone, .caution)
        XCTAssertEqual(panel.symbolName, "exclamationmark.triangle")
        XCTAssertFalse(panel.showsRecovery)
        XCTAssertFalse(panel.isLaunching)
    }

    func testProfileResetRequired_toneIsCaution_andNotRecovery() {
        let panel = PanelStatus.emptyReplacingStatus(.profileResetRequired)

        XCTAssertEqual(panel.tone, .caution)
        XCTAssertFalse(panel.showsRecovery)
    }

    func testConnectionError_toneIsError_andShowsRecovery() {
        let panel = PanelStatus.emptyReplacingStatus(.connectionError("transport closed"))

        XCTAssertEqual(panel.tone, .error)
        XCTAssertEqual(panel.symbolName, "exclamationmark.triangle")
        XCTAssertTrue(panel.showsRecovery)
        XCTAssertFalse(panel.isLaunching)
    }

    func testReady_headlineFollowsStatusDisplayText() {
        let panel = PanelStatus.emptyReplacingStatus(.chromeStarting)

        XCTAssertEqual(panel.headline, "Chrome 시작 중")
    }
}

private extension PanelStatus {
    static func emptyReplacingStatus(_ status: AppStatus) -> PanelStatus {
        PanelStatus(status: status)
    }
}
