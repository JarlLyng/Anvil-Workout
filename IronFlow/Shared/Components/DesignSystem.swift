//
//  DesignSystem.swift
//  IronFlow
//
//  Bruger IAMJARL Design Tokens. Import IAMJARLDesignTokens hvor tokens bruges.
//

import SwiftUI
import IAMJARLDesignTokens

extension View {
    /// Anvend IAMJARL spacing som padding.
    func designPadding(_ edges: Edge.Set = .all, _ size: CGFloat = DesignTokens.Spacing.md) -> some View {
        padding(edges, size)
    }
}
