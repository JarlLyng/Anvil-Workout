//
//  OnboardingView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/04/2026.
//

import SwiftUI
import IAMJARLDesignTokens
import PhosphorSwift

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            TabView(selection: $currentPage) {
                onboardingPage(
                    icon: Ph.barbell.fill,
                    iconColor: .primary,
                    title: "Welcome to Iron Workout",
                    subtitle: "Your personal training partner. Log workouts, track your progress and beat personal records."
                ) {
                    Button("Next") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                    .controlSize(.large)
                }
                .tag(0)

                onboardingPage(
                    icon: Ph.listBullets.fill,
                    iconColor: DesignTokens.ColorToken.State.success,
                    title: "Build Programs",
                    subtitle: "Create your own workout programs with exercises, sets and reps. Start a workout with a single tap."
                ) {
                    Button("Next") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                    .controlSize(.large)
                }
                .tag(1)

                onboardingPage(
                    icon: Ph.heartbeat.fill,
                    iconColor: DesignTokens.ColorToken.State.error,
                    title: "Health & Statistics",
                    subtitle: "Connect Apple Health for calories and heart rate. Track your volume, 1RM and streak over time."
                ) {
                    Button("Get Started") {
                        hasSeenOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                    .controlSize(.large)
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .overlay(alignment: .topTrailing) {
            if currentPage < 2 {
                Button("Skip") {
                    hasSeenOnboarding = true
                }
                .padding()
            }
        }
    }

    private func onboardingPage(
        icon: Image,
        iconColor: some ShapeStyle,
        title: String,
        subtitle: String,
        @ViewBuilder action: () -> some View = { EmptyView() }
    ) -> some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            icon
                .icon(size: 60)
                .foregroundStyle(iconColor)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
            }

            action()

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

#Preview {
    OnboardingView()
}
