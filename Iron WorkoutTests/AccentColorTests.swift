//
//  AccentColorTests.swift
//  Anvil WorkoutTests
//

import Testing
import SwiftUI
import UIKit
import IAMJARLDesignTokens
@testable import Iron_Workout

/// The AccentColor asset is the tint for everything SwiftUI's `.tint` does not reach, such as
/// the share sheet and the file picker that UIKit draws. It kept the design system's old light
/// primary (#CE63FF) after the token moved to #A435D2, and onboarding, which sat outside the
/// token tint, drew white text on it at 3:1. The asset has to be the token in both appearances.
@Suite("Accent colour")
struct AccentColorTests {

    private func components(_ color: UIColor, _ style: UIUserInterfaceStyle) -> [Int] {
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
    }

    @Test("The asset is the token's primary", arguments: [UIUserInterfaceStyle.light, .dark])
    func assetMatchesToken(style: UIUserInterfaceStyle) throws {
        let asset = try #require(UIColor(named: "AccentColor", in: Bundle(for: Exercise.self), compatibleWith: nil))
        let token = UIColor(DesignTokens.Common.primary(style == .dark ? .dark : .light))
        #expect(components(asset, style) == components(token, style))
    }
}
