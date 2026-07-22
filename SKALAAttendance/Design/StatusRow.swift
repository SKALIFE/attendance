import SwiftUI

/// A non-interactive status row showing an optional symbol, a label, and a
/// user-facing value (DESIGN.md §4 `StatusRow`).
///
/// Tone is optional. When provided, the symbol is rendered with the matching
/// system tint and the row stays accessible by reading label and value
/// together. Transitional tones use a small `ProgressView` in place of a
/// static symbol.
struct StatusRow: View {
    let tone: PanelStatus.Tone?
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.s2) {
            symbolView
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: DesignTokens.Spacing.s2)
            Text(value)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    @ViewBuilder
    private var symbolView: some View {
        if let tone {
            symbol(for: tone)
        } else {
            Image(systemName: "circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func symbol(for tone: PanelStatus.Tone) -> some View {
        switch tone {
        case .ready:
            Image(systemName: "checkmark.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.green)
                .accessibilityHidden(true)
        case .transitional:
            ProgressView()
                .controlSize(.small)
                .accessibilityHidden(true)
        case .caution:
            Image(systemName: "exclamationmark.triangle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
        case .error:
            Image(systemName: "exclamationmark.triangle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.red)
                .accessibilityHidden(true)
        }
    }
}
