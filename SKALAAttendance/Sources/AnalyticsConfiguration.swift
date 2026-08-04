import Foundation

struct AnalyticsConfiguration: Equatable, Sendable {
    let baseURL: URL?
    let websiteID: String?
    let hostname: String

    var isConfigured: Bool {
        baseURL != nil && !(websiteID?.isEmpty ?? true)
    }

    static let fromBundle: AnalyticsConfiguration = {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return AnalyticsConfiguration(
                baseURL: nil,
                websiteID: nil,
                hostname: "attendance-app.skalife.kr"
            )
        }

        let info = Bundle.main.infoDictionary ?? [:]
        let baseString = info["UMAMI_BASE_URL"] as? String ?? ""
        let websiteID = info["UMAMI_WEBSITE_ID"] as? String ?? ""
        let hostname = info["UMAMI_HOSTNAME"] as? String ?? "attendance-app.skalife.kr"
        return AnalyticsConfiguration(
            baseURL: URL(string: baseString).flatMap { $0.scheme == "https" ? $0 : nil },
            websiteID: websiteID.isEmpty ? nil : websiteID,
            hostname: hostname
        )
    }()
}
