import AppKit
import WebKit
import SwiftUI

@MainActor
final class AttendanceController: ObservableObject {

    let webView: WKWebView
    @Published var isLoading = true

    init() {
        let config = makeMobileWebViewConfiguration()
        let view = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 390, height: 780),
            configuration: config
        )
        view.customUserAgent = mobileUserAgent
        view.load(URLRequest(url: attendanceURL))
        self.webView = view
    }

    func reload() {
        webView.reload()
    }
}
