import SwiftUI

/// A menu-bar panel command row (DESIGN.md §4 `CommandRow`).
///
/// Renders an SF Symbol plus a Korean label as a full-width button row.
/// The default `MenuBarExtra` `.window`-style rendering supplies standard
/// hover, pressed, focus, and disabled states for plain buttons; the symbol
/// never replaces the label.
struct CommandRow: View {
    let title: String
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
            }
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel(title)
    }
}
