import Foundation
import XCTest

final class ReleaseMetadataTests: XCTestCase {
    func testAppReleaseMetadataDefinesSparkleUpdateConfiguration() throws {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let appInfo = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Resources/Info.plist")
        let metadata = try XCTUnwrap(NSDictionary(contentsOf: appInfo) as? [String: Any])

        XCTAssertEqual(
            metadata["SUFeedURL"] as? String,
            "https://raw.githubusercontent.com/skalife/attendance-appcast/main/appcast.xml"
        )

        XCTAssertEqual(
            metadata["SUPublicEDKey"] as? String,
            "Wd3jeI01lpAYggUMHynFMN2FmRbwldZUGyao2hS4lik="
        )
    }
}
