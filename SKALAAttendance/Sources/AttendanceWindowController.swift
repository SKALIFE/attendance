import AppKit
import Combine
import WebKit

/// Manages the independent NSWindow that hosts the attendance WKWebView.
///
/// The window is created lazily on first open and kept alive for the
/// lifetime of the app.  Closing the window hides it; calling ``openAttendance()``
/// brings it back without losing the page state.
@MainActor
final class AttendanceWindowController: ObservableObject {

    // MARK: Published state

    @Published private(set) var isWindowVisible = false
    @Published private(set) var statusText = "준비됨"
    @Published private(set) var statusSymbol = "checkmark.circle"

    // MARK: Private state

    private var window: NSWindow?
    private var webView: WKWebView?
    private var navigationDelegate: AttendanceNavigationDelegate?
    private var windowDelegate: WindowDelegate?

    init() {
        NotificationCenter.default.addObserver(
            forName: .openAttendance,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.openAttendance() }
        }
    }

    // MARK: Actions

    /// Creates the window (if needed) and brings it to the front.
    func openAttendance() {
        ensureWindow()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isWindowVisible = true
    }

    /// Brings an existing window to the front without reloading.
    func bringToFront() {
        guard window != nil else {
            openAttendance()
            return
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Reloads the current page in the web view.
    func reload() {
        webView?.reload()
    }

    // MARK: Window lifecycle

    private func ensureWindow() {
        guard window == nil else { return }

        let config = makeMobileWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = mobileUserAgent
        view.load(URLRequest(url: attendanceURL))

        // Track loading state for the menu status line.
        let navDelegate = AttendanceNavigationDelegate { [weak self] loading in
            guard let self else { return }
            self.statusText = loading ? "로딩 중…" : "준비됨"
            self.statusSymbol = loading ? "arrow.2.circlepath" : "checkmark.circle"
        }
        view.navigationDelegate = navDelegate
        self.navigationDelegate = navDelegate

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "SKALA 출결"
        win.contentView = view
        win.isReleasedWhenClosed = false
        win.titlebarAppearsTransparent = false

        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            let w: CGFloat = 430
            let h: CGFloat = min(900, vf.height - 60)
            win.setFrame(
                NSRect(x: vf.midX - w / 2, y: vf.midY - h / 2, width: w, height: h),
                display: true
            )
        } else {
            win.center()
        }

        let delegate = WindowDelegate()
        delegate.onWillClose = { [weak self] in
            Task { @MainActor in self?.isWindowVisible = false }
        }
        delegate.onBecomeKey = { [weak self] in
            Task { @MainActor in self?.isWindowVisible = true }
        }
        win.delegate = delegate
        self.windowDelegate = delegate

        self.window = win
        self.webView = view
    }
}

// MARK: - Window delegate

/// Separate NSObject delegate to avoid NSObjectProtocol conformance issues
/// on the ObservableObject controller.
private final class WindowDelegate: NSObject, NSWindowDelegate {
    var onWillClose: (() -> Void)?
    var onBecomeKey: (() -> Void)?

    func windowWillClose(_ notification: Notification) {
        onWillClose?()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        onBecomeKey?()
    }
}

// MARK: - Navigation delegate

/// Minimal WKNavigationDelegate that reports loading state.
/// It does NOT inspect page content, cookies, or URLs.
private final class AttendanceNavigationDelegate: NSObject, WKNavigationDelegate {

    private let onLoadingChange: (Bool) -> Void

    init(onLoadingChange: @escaping (Bool) -> Void) {
        self.onLoadingChange = onLoadingChange
    }

    func webView(_ webView: WKWebView,
                 didStartProvisionalNavigation navigation: WKNavigation!) {
        onLoadingChange(true)
    }

    func webView(_ webView: WKWebView,
                 didFinish navigation: WKNavigation!) {
        onLoadingChange(false)
    }

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        onLoadingChange(false)
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        onLoadingChange(false)
    }
}
