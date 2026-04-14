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
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            TabView(selection: $currentPage) {
                onboardingPage(
                    icon: Ph.barbell.fill,
                    iconColor: .primary,
                    title: "Velkommen til Iron Workout",
                    subtitle: "Din personlige tr\u{00E6}ningspartner. Log tr\u{00E6}ninger, f\u{00F8}lg din progression og sl\u{00E5} personlige rekorder."
                )
                .tag(0)

                onboardingPage(
                    icon: Ph.listBullets.fill,
                    iconColor: DesignTokens.ColorToken.State.success,
                    title: "Opret programmer",
                    subtitle: "Byg dine egne tr\u{00E6}ningsprogrammer med \u{00F8}velser, s\u{00E6}t og reps. Start en tr\u{00E6}ning med \u{00E9}t tryk."
                )
                .tag(1)

                onboardingPage(
                    icon: Ph.heartbeat.fill,
                    iconColor: DesignTokens.ColorToken.State.error,
                    title: "Health & Statistik",
                    subtitle: "Forbind Apple Health for kalorier og puls. F\u{00F8}lg din volumen, 1RM og streak over tid."
                ) {
                    Button("Kom i gang") {
                        hasSeenOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
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
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
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
