import XCTest
@testable import SKALAAttendance

final class ReleaseTests: XCTestCase {
    func testAppConstants_whenReleased_matchProductSpec() {
        XCTAssertEqual(AppConstants.appName, "SKALA Attendance")
        XCTAssertEqual(AppConstants.bundleIdentifier, "kr.skalife.attendance")
        XCTAssertEqual(AppConstants.attendanceURL.absoluteString, "https://att.skala-ai.com/")
        XCTAssertEqual(AppConstants.appcastURL.absoluteString, "https://skalife.github.io/attendance/appcast.xml")
    }

    func testReleaseWorkflow_whenConfigured_requiresProductionUmamiVariables() throws {
        let workflow = try repositoryText(".github/workflows/release.yml")

        XCTAssertTrue(workflow.contains("UMAMI_BASE_URL: ${{ vars.UMAMI_BASE_URL }}"))
        XCTAssertTrue(workflow.contains("UMAMI_WEBSITE_ID: ${{ vars.UMAMI_WEBSITE_ID }}"))
        XCTAssertTrue(workflow.contains("UMAMI_HOSTNAME: ${{ vars.UMAMI_HOSTNAME }}"))
        XCTAssertTrue(workflow.contains("SPARKLE_PUBLIC_KEY APPCAST_REPO_TOKEN UMAMI_BASE_URL UMAMI_WEBSITE_ID UMAMI_HOSTNAME"))
    }

    func testSecretsExample_usesGenericUmamiGatewayAndPlaceholders() throws {
        let secrets = try repositoryText("Config/Secrets.xcconfig.example")

        XCTAssertTrue(secrets.contains("UMAMI_BASE_URL = https://gateway.umami.is"))
        XCTAssertTrue(secrets.contains("UMAMI_WEBSITE_ID = replace-with-website-id"))
        XCTAssertTrue(secrets.contains("UMAMI_HOSTNAME = attendance-app.skalife.kr"))
    }

    func testImplementationStatus_whenSparklePublicKeyIsPlaceholder_doesNotClaimLocalKeyComplete() throws {
        let status = try repositoryText("docs/IMPLEMENTATION_STATUS.md")

        XCTAssertFalse(status.contains("- [x] EdDSA public key\n"))
        XCTAssertTrue(status.contains("EdDSA public key injection"))
    }

    func testReleaseWorkflow_whenValidatingTag_usesSemVerRegex() throws {
        let workflow = try repositoryText(".github/workflows/release.yml")

        XCTAssertTrue(workflow.contains("GITHUB_REF_NAME"))
        XCTAssertTrue(workflow.contains("[1-9][0-9]*"))
        XCTAssertTrue(workflow.contains("Validate SemVer"))
    }

    func testReleaseSetup_whenDocumentingSparkle_explainsKeyGenerationAndSecretStorage() throws {
        let setup = try repositoryText("docs/release-setup.md")

        XCTAssertTrue(setup.contains("generate_keys\" -x"))
        XCTAssertTrue(setup.contains("SPARKLE_KEY_EXPORT"))
        XCTAssertTrue(setup.contains("SPARKLE_EDDSA_PRIVATE_KEY"))
        XCTAssertTrue(setup.contains("SUPublicEDKey"))
        XCTAssertTrue(setup.contains("commit하지 않습니다"))
    }

    func testSemVerRegex_acceptsValidTagsRejectsInvalidTags() throws {
        let pattern = #"^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?$"#
        let regex = try NSRegularExpression(pattern: pattern)

        let validTags = ["v1.0.0", "v1.2.3", "v10.20.30", "v1.0.0-alpha", "v1.0.0-rc.1", "v1.0.0-beta.2"]
        let invalidTags = ["v01.0.0", "v1.0", "v1.0.0-", "1.0.0", "v1.0.0..1", "v1.2.3.4"]

        for tag in validTags {
            let range = NSRange(tag.startIndex..., in: tag)
            XCTAssertNotNil(regex.firstMatch(in: tag, range: range), "Expected valid tag: \(tag)")
        }

        for tag in invalidTags {
            let range = NSRange(tag.startIndex..., in: tag)
            XCTAssertNil(regex.firstMatch(in: tag, range: range), "Expected invalid tag: \(tag)")
        }
    }

    private func repositoryText(_ relativePath: String, filePath: String = #filePath) throws -> String {
        let url = URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
