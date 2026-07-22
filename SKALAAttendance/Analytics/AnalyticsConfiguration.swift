import Foundation

struct AnalyticsConfiguration: Equatable, Sendable {
    let baseURL: URL?
    let websiteID: String?
    let hostname: String

    var isConfigured: Bool {
        baseURL != nil && websiteID?.isEmpty == false
    }

    static var fromBundle: AnalyticsConfiguration {
        let info = Bundle.main.infoDictionary ?? [:]
        let baseString = info["UMAMI_BASE_URL"] as? String
        let websiteID = info["UMAMI_WEBSITE_ID"] as? String
        let hostname = (info["UMAMI_HOSTNAME"] as? String) ?? AppConstants.analyticsHostname
        return AnalyticsConfiguration(
            baseURL: baseString.flatMap { URL(string: $0) }.flatMap(AnalyticsConfiguration.requireHTTPS),
            websiteID: websiteID,
            hostname: hostname.isEmpty ? AppConstants.analyticsHostname : hostname
        )
    }

    private static func requireHTTPS(_ url: URL) -> URL? {
        url.scheme == "https" ? url : nil
    }
}
