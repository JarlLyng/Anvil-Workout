//
//  DashboardSubviews.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/04/2026.
//

import SwiftUI
import IAMJARLDesignTokens
import PhosphorSwift

// MARK: - DashboardCard

struct DashboardCard<Icon: View>: View {
    let title: String
    let value: String
    let icon: Icon

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                icon
                Spacer()
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(value)
                    .font(.title2.bold())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }
}

// MARK: - WeeklyPlanRow

struct WeeklyPlanRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let weeklyPlan: [Int: String]
    var onEdit: () -> Void

    static let dayAbbreviations = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.sm), count: 4)

    var body: some View {
        let calendar = Calendar.current
        // ISO weekday: Mon=2..Sun=1 -> map to 0-based index
        let todayWeekday = calendar.component(.weekday, from: .now)
        let todayIndex = (todayWeekday + 5) % 7  // Mon=0, Tue=1, ..., Sun=6

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("Weekly Plan")
                    .font(.title2.bold())
                Spacer()
                Button {
                    onEdit()
                } label: {
                    Ph.pencilSimple.regular
                        .icon()
                }
                .accessibilityLabel("Edit weekly plan")
            }

            LazyVGrid(columns: Self.columns, spacing: DesignTokens.Spacing.sm) {
                ForEach(0..<7, id: \.self) { index in
                    let templateName = weeklyPlan[index]
                    let isToday = index == todayIndex

                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Text(Self.dayAbbreviations[index])
                            .font(.caption.bold())
                            .foregroundStyle(isToday ? DesignTokens.Common.OnPrimary.text(colorScheme) : .secondary)

                        Text(templateName ?? "\u{2014}")
                            .font(.caption2)
                            .foregroundStyle(isToday ? DesignTokens.Common.OnPrimary.text(colorScheme).opacity(0.9) : .primary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                            .fill(isToday ? Color.accentColor : Color.clear)
                            .background(.regularMaterial.opacity(isToday ? 0 : 1), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                    }
                    .onTapGesture {
                        onEdit()
                    }
                }
            }
        }
    }
}
