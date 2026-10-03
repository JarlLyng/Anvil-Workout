//
//  SummaryCards.swift
//  Anvil Workout
//
//  The card and the large number that Stats, the completion screen and a workout in
//  History are built from, so the three read as one app.
//

import SwiftUI
import IAMJARLDesignTokens

/// A grouped card with a small uppercase title.
struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }
}

/// A large number with a small label under it.
struct BigNumber: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Big numbers side by side, stacked at the accessibility text sizes so none is cut short.
struct NumberRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md))
        layout { content() }
    }
}

/// A name with a value at the end of the line, or under it when both do not fit, as on
/// the home screen's next workout and the completion screen's exercises.
struct NameValueLine: View {
    let name: String
    let value: String
    var valueStyle: HierarchicalShapeStyle = .secondary

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(name).lineLimit(1)
                Spacer(minLength: DesignTokens.Spacing.md)
                Text(value).monospacedDigit().foregroundStyle(valueStyle).lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                Text(value).monospacedDigit().foregroundStyle(valueStyle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
