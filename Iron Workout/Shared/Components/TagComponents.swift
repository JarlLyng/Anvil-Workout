//
//  TagComponents.swift
//  Anvil Workout
//
//  Reusable chip + wrapping-layout primitives used for template tags.
//

import SwiftUI
import IAMJARLDesignTokens
import PhosphorSwift

// MARK: - FlowLayout

/// A simple left-to-right wrapping layout: lays subviews in rows, wrapping to the
/// next line when the proposed width is exceeded. Used for tag chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0 && rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                widest = max(widest, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += rowWidth > 0 ? spacing + size.width : size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        widest = max(widest, rowWidth)
        return CGSize(width: maxWidth == .infinity ? widest : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - TagChip

/// A tag pill. Pass `onRemove` to show a delete affordance (used in the editor).
struct TagChip: View {
    let text: String
    var onRemove: (() -> Void)?

    init(text: String, onRemove: (() -> Void)? = nil) {
        self.text = text
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption.weight(.medium))
            if let onRemove {
                Button(action: onRemove) {
                    Ph.x.bold.icon(size: 10)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove tag \(text)")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
    }
}

// MARK: - TagFilterChip

/// A selectable tag pill used in the filter bar.
struct TagFilterChip: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? DesignTokens.Common.OnPrimary.text(colorScheme) : .primary)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background {
                    if isSelected {
                        Capsule().fill(DesignTokens.Common.primary(colorScheme))
                    } else {
                        Capsule().fill(.regularMaterial)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
