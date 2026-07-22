import SwiftUI

/// SKALA Attendance design tokens for native SwiftUI surfaces.
///
/// Use these instead of ad-hoc literals so the menu-bar panel, onboarding,
/// and settings stay consistent with DESIGN.md. Tokens cover spacing,
/// corner radius, panel/window sizes, and semantic color helpers. All values
/// trace back to DESIGN.md §2 (`Foundations and tokens`).
enum DesignTokens {
    /// Linear spacing scale (DESIGN.md §2 `Spacing and shape`).
    enum Spacing {
        /// 4 pt — icon to label, tight inline detail.
        static let s1: CGFloat = 4
        /// 8 pt — related controls and compact rows.
        static let s2: CGFloat = 8
        /// 12 pt — row groups and card interior rhythm.
        static let s3: CGFloat = 12
        /// 16 pt — standard section content spacing.
        static let s4: CGFloat = 16
        /// 24 pt — window padding and major groups.
        static let s6: CGFloat = 24
        /// 32 pt — major onboarding separation.
        static let s8: CGFloat = 32
    }

    /// Corner radius scale (DESIGN.md §2 `Spacing and shape`).
    enum Radius {
        /// 8 pt — custom grouped surface only when native controls do not
        /// supply shape.
        static let control: CGFloat = 8
        /// 12 pt — window-style panel grouping only.
        static let panel: CGFloat = 12
    }

    /// Menu-bar panel width band (DESIGN.md §3).
    enum Panel {
        /// 300 pt lower bound for useful content.
        static let minWidth: CGFloat = 300
        /// 320 pt comfortable default.
        static let idealWidth: CGFloat = 320
        /// 360 pt upper bound before panel feels oversized.
        static let maxWidth: CGFloat = 360
    }

    /// Onboarding window metrics (DESIGN.md §3).
    enum Onboarding {
        /// 520 pt baseline content width.
        static let width: CGFloat = 520
        /// 24 pt outer padding.
        static let outerPadding: CGFloat = 24
    }

    /// Settings window metrics (DESIGN.md §3).
    enum SettingsLayout {
        /// 560 pt baseline width.
        static let width: CGFloat = 560
        /// 420 pt baseline height.
        static let height: CGFloat = 420
    }
}

/// Semantic color helpers for native SwiftUI surfaces.
///
/// Always pair state colors with both text and an SF Symbol so tone is never
/// the only signal (DESIGN.md §2, §6).
extension Color {
    /// `Color(nsColor: .windowBackgroundColor)` — onboarding and settings
    /// canvas.
    static let skalaCanvas = Color(nsColor: .windowBackgroundColor)
}
