import Foundation
import WebKit

/// Mobile Chrome (Android Pixel 9) User-Agent string.
/// Used to make the attendance site serve its mobile layout.
let mobileUserAgent =
    "Mozilla/5.0 (Linux; Android 15; Pixel 9) "
    + "AppleWebKit/537.36 (KHTML, like Gecko) "
    + "Chrome/131.0.0.0 Mobile Safari/537.36"

/// The official attendance URL.
let attendanceURL = URL(string: "https://att.skala-ai.com/")!

/// Builds a WKWebViewConfiguration optimised for mobile attendance.
///
/// - Persistent data store: login cookies survive app restarts.
/// - Mobile content mode: WKWebView prefers mobile layout regardless of viewport.
/// - No JavaScript automation or content inspection.
@MainActor
func makeMobileWebViewConfiguration() -> WKWebViewConfiguration {
    let config = WKWebViewConfiguration()

    // Persistent store so login state (cookies, local storage) survives.
    config.websiteDataStore = WKWebsiteDataStore.default()

    // Force mobile rendering.
    config.defaultWebpagePreferences.preferredContentMode = .mobile

    // Let the page use its own viewport meta tag.
    config.suppressesIncrementalRendering = false

    return config
}
