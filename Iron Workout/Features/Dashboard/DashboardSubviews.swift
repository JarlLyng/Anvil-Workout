//
//  DashboardSubviews.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/04/2026.
//

import SwiftUI
import IAMJARLDesignTokens
import PhosphorSwift

// MARK: - Section label

/// "UP NEXT", "THIS WEEK": the small heading over each home card.
struct DashboardSectionLabel<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing()
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
    }
}

extension DashboardSectionLabel where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

// MARK: - Up next

/// The workout to do next, with its exercises and the one button the home screen is for.
struct UpNextCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    /// "Planned for today · last done 3 days ago".
    let context: String
    /// Exercise name and plan ("5 × 5 · 40 kg"), in program order.
    let lines: [(name: String, plan: String)]
    var onStart: () -> Void

    private static let shownLines = 5

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(context)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !lines.isEmpty {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(Array(lines.prefix(Self.shownLines).enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline) {
                            Text(line.name)
                                .lineLimit(1)
                            Spacer(minLength: DesignTokens.Spacing.md)
                            Text(line.plan)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .font(.subheadline)
                    }
                    if lines.count > Self.shownLines {
                        Text("+\(lines.count - Self.shownLines) more")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Button(action: onStart) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Ph.play.fill.icon(size: 18)
                    Text("Start Workout")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
            .controlSize(.large)
            .accessibilityLabel("Start \(title)")
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }
}

// MARK: - Start here

/// What a new lifter sees instead of an empty home screen: the two ways to get a first
/// program, and where importing lives.
struct StartHereCard: View {
    @Environment(\.colorScheme) private var colorScheme
    var onLibrary: () -> Void
    var onCreate: () -> Void
    var onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Start with a program")
                    .font(.title3.weight(.semibold))
                Text("Pick a proven one like StrongLifts 5×5 and change anything you like, or build your own.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button(action: onLibrary) {
                Label { Text("Browse Program Library").fontWeight(.semibold) } icon: { Ph.bookOpen.regular.icon(size: 18) }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
            .controlSize(.large)
            Button(action: onCreate) {
                Text("Build My Own").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Button(action: onImport) {
                Label { Text("Import history from Strong or Hevy") } icon: { Ph.downloadSimple.regular.icon(size: 16) }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }
}

// MARK: - This week

/// The week at a glance: a strip of days (trained, planned, nothing) and three numbers.
/// A planned day that passed without a workout is shown as planned, not as missed; the
/// strip records, it does not judge.
struct WeekCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let week: TrainingSummary.Week
    let lastWeekWorkouts: Int
    let streak: Int
    let volumeText: String
    /// Planned program names by weekday index, Monday = 0.
    let planned: [Int: [String]]
    var onEditPlan: () -> Void

    private let calendar = Calendar.current

    private static let fullNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private static let initials = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let today = TrainingSummary.weekdayIndex(of: .now, calendar: calendar)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: 0) {
                ForEach(TrainingSummary.weekOrder(calendar: calendar), id: \.self) { index in
                    dayColumn(index, isToday: index == today)
                        .frame(maxWidth: .infinity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onEditPlan() }

            if week.workouts == 0 && lastWeekWorkouts == 0 && streak == 0 {
                // A plan but no training yet: a row of zeros says nothing.
                Text("Your week fills in as you train.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                    metric(value: "\(week.workouts)", label: week.workouts == 1 ? "workout" : "workouts")
                    metric(value: volumeText, label: "volume")
                    metric(value: "\(streak)", label: "day streak")
                }

                Text("Last week: \(lastWeekWorkouts) \(lastWeekWorkouts == 1 ? "workout" : "workouts")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }

    private func dayColumn(_ index: Int, isToday: Bool) -> some View {
        let trained = week.trainedDays.contains(index)
        let plannedNames = planned[index] ?? []
        return VStack(spacing: DesignTokens.Spacing.sm) {
            Text(Self.initials[index])
                .font(.caption.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? .primary : .secondary)
            ZStack {
                if trained {
                    Circle().fill(DesignTokens.Common.primary(colorScheme))
                        .frame(width: 12, height: 12)
                } else if !plannedNames.isEmpty {
                    Circle().strokeBorder(.secondary, lineWidth: 1.5)
                        .frame(width: 12, height: 12)
                } else {
                    Circle().fill(.quaternary)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 12)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background {
            if isToday {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm).fill(.quaternary.opacity(0.6))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.fullNames[index])\(isToday ? ", today" : "")")
        .accessibilityValue(dayValue(trained: trained, planned: plannedNames))
        .accessibilityHint("Edit weekly plan")
        .accessibilityAddTraits(.isButton)
    }

    private func dayValue(trained: Bool, planned: [String]) -> String {
        let plan = planned.isEmpty ? "" : "Planned: \(planned.joined(separator: ", "))"
        if trained { return plan.isEmpty ? "Trained" : "Trained. \(plan)" }
        return plan.isEmpty ? "Nothing planned" : plan
    }

    private func metric(value: String, label: String) -> some View {
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

// MARK: - Recent workout

struct RecentWorkoutRow: View {
    let name: String
    let dateLabel: String
    /// "32 min · 15 sets · 1,240 kg"
    let detail: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: DesignTokens.Spacing.sm)
                    Text(dateLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Ph.caretRight.regular
                .icon(size: 14)
                .foregroundStyle(.tertiary)
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(dateLabel), \(detail)")
    }
}
