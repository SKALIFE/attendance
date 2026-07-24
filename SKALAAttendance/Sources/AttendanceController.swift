import AppKit
import WebKit
import SwiftUI
import os

@MainActor
final class AttendanceController: ObservableObject {

    let webView: WKWebView
    @Published var isLoading = true

    private let analyticsConfig = AnalyticsConfiguration.fromBundle
    private let analyticsClient: AnalyticsClient
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "kr.skalife.attendance", category: "app")

    init() {
        let config = makeMobileWebViewConfiguration()
        let view = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 390, height: 780),
            configuration: config
        )
        view.customUserAgent = mobileUserAgent
        view.load(URLRequest(url: attendanceURL))
        self.webView = view
        self.analyticsClient = AnalyticsClient(configuration: analyticsConfig)

        trackLifecycleEvents()
    }

    func reload() {
        webView.reload()
    }

    var analyticsEnabled: Bool {
        get { defaults.object(forKey: "analyticsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "analyticsEnabled") }
    }

    private func trackLifecycleEvents() {
        let installID: String
        if let existing = defaults.string(forKey: "anonymousInstallID") {
            installID = existing
        } else {
            installID = UUID().uuidString
            defaults.set(installID, forKey: "anonymousInstallID")
        }

        let enabled = analyticsEnabled

        if !defaults.bool(forKey: "installEventSent") {
            Task {
                await analyticsClient.track(.install, distinctID: installID, analyticsEnabled: enabled)
                defaults.set(true, forKey: "installEventSent")
            }
        }

        Task {
            await analyticsClient.track(.appLaunch, distinctID: installID, analyticsEnabled: enabled)
            await analyticsClient.track(.attendanceOpen, distinctID: installID, analyticsEnabled: enabled)
        }

        logger.info("app launched, analytics configured: \(self.analyticsConfig.isConfigured)")
    }
}
