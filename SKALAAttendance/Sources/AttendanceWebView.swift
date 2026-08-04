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

/// The only page where user-requested profile filling is allowed.
let authenticationURL = URL(string: "https://auth.skala-ai.com/")!

func isAuthenticationPageURL(_ url: URL?) -> Bool {
    guard let url else {
        return false
    }

    return url.scheme?.lowercased() == authenticationURL.scheme
        && url.host?.lowercased() == authenticationURL.host
        && (url.port == nil || url.port == 443)
}

enum WebViewLoadFailureReason: String, Equatable, Sendable {
    case offline
    case timeout
    case dns
    case refused
    case tls
    case unknown

    static func classify(_ error: Error) -> Self? {
        let error = error as NSError

        guard error.domain == NSURLErrorDomain else {
            return .unknown
        }

        switch error.code {
        case NSURLErrorCancelled:
            return nil
        case NSURLErrorNotConnectedToInternet:
            return .offline
        case NSURLErrorTimedOut:
            return .timeout
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return .dns
        case NSURLErrorCannotConnectToHost:
            return .refused
        case NSURLErrorSecureConnectionFailed,
            NSURLErrorServerCertificateHasBadDate,
            NSURLErrorServerCertificateUntrusted,
            NSURLErrorServerCertificateHasUnknownRoot,
            NSURLErrorServerCertificateNotYetValid,
            NSURLErrorClientCertificateRejected,
            NSURLErrorClientCertificateRequired:
            return .tls
        default:
            return .unknown
        }
    }
}

@MainActor
final class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    private let onNavigationFailure: (WebViewLoadFailureReason) -> Void
    private let onNavigationFinished: (URL?) -> Void

    init(onNavigationFailure: @escaping (WebViewLoadFailureReason) -> Void) {
        self.onNavigationFailure = onNavigationFailure
        self.onNavigationFinished = { _ in }
    }

    init(
        onNavigationFailure: @escaping (WebViewLoadFailureReason) -> Void,
        onNavigationFinished: @escaping (URL?) -> Void
    ) {
        self.onNavigationFailure = onNavigationFailure
        self.onNavigationFinished = onNavigationFinished
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation?,
        withError error: Error
    ) {
        guard let reason = WebViewLoadFailureReason.classify(error) else {
            return
        }

        onNavigationFailure(reason)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation?,
        withError error: Error
    ) {
        guard let reason = WebViewLoadFailureReason.classify(error) else {
            return
        }

        onNavigationFailure(reason)
    }

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation?
    ) {
        onNavigationFinished(webView.url)
    }
}

/// Builds a WKWebViewConfiguration optimised for mobile attendance.
///
/// - Persistent data store: login cookies survive app restarts.
/// - Mobile content mode: WKWebView prefers mobile layout regardless of viewport.
/// - No page clicks or submissions; profile filling requires an explicit user action.
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
