import Foundation

/// Pure presentation model that maps an `AppStatus` plus operational
/// descriptions to the symbol, tone, and label used by the menu-bar panel
/// and shared status rows.
///
/// Owned by DESIGN.md §4 `StatusRow` and §5 (`Symbols, copy, and feedback`).
/// Tone is never the only signal: callers always pair `tone` with
/// `headline` and a symbol so users can scan state without relying on color
/// alone.
struct PanelStatus: Equatable, Sendable {
    /// Coarse tone used to choose a tint and symbol family.
    enum Tone: Equatable, Sendable {
        case ready
        case transitional
        case caution
        case error
    }

    let status: AppStatus
    /// Convenience for tests and previews.
    static let empty = PanelStatus(status: .ready)

    /// Coarse tone derived from `status`. Transitional tones cover any
    /// launch-stage status (Chrome starting, CDP connecting, attendance
    /// opening).
    var tone: Tone {
        switch status {
        case .ready: .ready
        case .chromeStarting, .cdpConnecting, .openingAttendance: .transitional
        case .chromeMissing, .profileResetRequired: .caution
        case .connectionError: .error
        }
    }

    /// SF Symbol that pairs with `tone`. Transitional tones prefer a real
    /// `ProgressView` in the view layer; this symbol is a static fallback.
    var symbolName: String {
        switch tone {
        case .ready: "checkmark.circle"
        case .transitional: "arrow.triangle.2.circlepath"
        case .caution, .error: "exclamationmark.triangle"
        }
    }

    /// Short Korean headline shown next to the symbol.
    var headline: String { status.displayText }

    /// Whether the panel should reveal the recovery section. Only
    /// connection errors expose the diagnostics / reset / report row group.
    var showsRecovery: Bool {
        if case .connectionError = status { return true }
        return false
    }

    /// Returns `true` when an attendance launch is in progress. Used to
    /// disable mutually exclusive launch buttons.
    var isLaunching: Bool {
        switch status {
        case .chromeStarting, .cdpConnecting, .openingAttendance: true
        default: false
        }
    }
}
