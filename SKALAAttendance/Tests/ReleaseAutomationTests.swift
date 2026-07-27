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

        let publicKey = try XCTUnwrap(metadata["SUPublicEDKey"] as? String)
        XCTAssertEqual(Data(base64Encoded: publicKey)?.count, 32)
    }
}
