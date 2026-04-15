//
//  DesignSystem.swift
//  Iron Workout
//

import SwiftUI
import IAMJARLDesignTokens

// MARK: - Phosphor Icon Helpers

/// Reduces repeated `.resizable().aspectRatio(contentMode: .fit).frame(width:height:)` chains
/// that cause type-checker slowdowns across ~50 call sites.
extension Image {
    func icon(size: CGFloat = 20) -> some View {
        self.resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
