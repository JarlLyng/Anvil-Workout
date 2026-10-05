//
//  OnboardingView.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/04/2026.
//
//  First launch: one decision per step. The unit to lift in, whether workouts go to Apple
//  Health (asked here, at home, rather than by the system at the start of the first
//  workout), and how to start: a program from the library, history from Strong or Hevy,
//  or a program of your own. Each start leads straight into the app's own flow for it.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
import PhosphorSwift

struct OnboardingView: View {
    private enum Step { case unit, health, start }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnit: String = WeightUnit.kg.rawValue

    @State private var step: Step = Self.initialStep

    /// The first step, or the choice of how to start for a Debug screenshot capture.
    private static var initialStep: Step {
        #if DEBUG
        if ScreenshotMode.screen == .onboarding { return .start }
        #endif
        return .unit
    }
    @State private var healthRequestInProgress = false
    @State private var showLibrary = false
    @State private var importedProgram = false
    @State private var showImporter = false
    @State private var importedWorkouts: Int?
    @State private var templateToBuild: WorkoutTemplate?
    @State private var builtTemplate: WorkoutTemplate?
    @State private var errorMessage: String?

    private let health = HealthKitService.shared

    private var steps: [Step] { health.isAvailable ? [.unit, .health, .start] : [.unit, .start] }
    private var stepIndex: Int { steps.firstIndex(of: step) ?? 0 }
    private var device: String { UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone" }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Group {
                switch step {
                case .unit: unitStep
                case .health: healthStep
                case .start: startStep
                }
            }
            .id(step)
            .transition(.opacity)
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear(perform: defaultUnitFromRegion)
        .sheet(isPresented: $showLibrary, onDismiss: { if importedProgram { finish() } }) {
            ProgramLibraryView { _ in
                importedProgram = true
                showLibrary = false
            }
        }
        .sheet(item: $templateToBuild, onDismiss: finishBuilding) { template in
            NavigationStack {
                CreateEditTemplateView(template: template, isNew: true)
            }
        }
        .workoutImport(isPresented: $showImporter) { summary in
            importedWorkouts = summary.importedSessions
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Top bar

    /// Back on every step after the first, and one dot per step.
    private var topBar: some View {
        HStack {
            Button {
                go(to: steps[max(stepIndex - 1, 0)])
            } label: {
                Ph.caretLeft.regular.icon(size: 22)
                    .frame(width: 44, height: 44)
            }
            .opacity(stepIndex > 0 ? 1 : 0)
            .disabled(stepIndex == 0)
            .accessibilityLabel("Back")

            Spacer()
            HStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == stepIndex ? AnyShapeStyle(DesignTokens.Common.primary(colorScheme)) : AnyShapeStyle(Color.secondary.opacity(0.3)))
                        .frame(width: index == stepIndex ? 20 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(stepIndex + 1) of \(steps.count)")
            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
    }

    // MARK: - Steps

    private var unitStep: some View {
        StepLayout {
            StepHeader(
                icon: Ph.barbell.fill,
                tint: DesignTokens.Common.primary(colorScheme),
                title: "Welcome to Anvil Workout",
                message: "Plan your programs, log each set in the gym and see how your lifts move. Your training log stays on this \(device), and there is no account to make."
            )
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Which unit do you lift in?")
                    .font(.headline)
                unitOption(.kg, title: "Kilograms", example: "100 kg")
                unitOption(.lbs, title: "Pounds", example: "225 lb")
                Text("You can change this any time in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } actions: {
            primaryButton("Next") { go(to: steps[stepIndex + 1]) }
        }
    }

    private var healthStep: some View {
        StepLayout {
            StepHeader(
                icon: Ph.heart.fill,
                tint: DesignTokens.ColorToken.State.error,
                title: "Apple Health",
                message: "Anvil can save each finished workout to Health, and show the calories and heart rate your watch or another source recorded during it."
            )
            Text("If you skip this, your \(device) asks when you start your first workout. You can change it later in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } actions: {
            // Neutral wording before a system permission prompt, as Apple asks (5.1.1(iv)).
            primaryButton("Continue", busy: healthRequestInProgress, action: requestHealth)
            Button("Not now") { go(to: .start) }
                .controlSize(.large)
                .disabled(healthRequestInProgress)
        }
    }

    private var startStep: some View {
        StepLayout {
            Text("How do you want to start?")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DesignTokens.Spacing.lg)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: DesignTokens.Spacing.md) {
                StartOption(
                    icon: Ph.bookOpen.regular,
                    title: "Pick a proven program",
                    detail: "StrongLifts 5×5, Starting Strength, GZCLP and more, yours to change."
                ) { showLibrary = true }

                if let importedWorkouts {
                    StartOption(
                        icon: Ph.checkCircle.fill,
                        iconTint: DesignTokens.ColorToken.State.success,
                        title: "History imported",
                        detail: "\(importedWorkouts) \(importedWorkouts == 1 ? "workout is" : "workouts are") in your history. Now pick or build a program to train with.",
                        action: nil
                    )
                } else {
                    StartOption(
                        icon: Ph.downloadSimple.regular,
                        title: "Import from Strong or Hevy",
                        detail: "Bring your workout history. You see what comes across before anything is saved."
                    ) { showImporter = true }
                }

                StartOption(
                    icon: Ph.pencilSimpleLine.regular,
                    title: "Build my own",
                    detail: "Choose the exercises, sets, reps, weight and rest."
                ) { buildOwn() }
            }
        } actions: {
            Button(importedWorkouts == nil ? "Look around first" : "Go to the app") { finish() }
                .controlSize(.large)
        }
    }

    private func unitOption(_ unit: WeightUnit, title: String, example: String) -> some View {
        let selected = weightUnit == unit.rawValue
        let primary = DesignTokens.Common.primary(colorScheme)
        return Button {
            weightUnit = unit.rawValue
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(example)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                (selected ? Ph.checkCircle.fill : Ph.circle.regular)
                    .icon(size: 26)
                    .foregroundStyle(selected ? primary : Color.secondary)
            }
            .padding(DesignTokens.Spacing.lg)
            .contentShape(Rectangle())
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .strokeBorder(selected ? primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func primaryButton(_ title: String, busy: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Text(title).fontWeight(.semibold).opacity(busy ? 0 : 1)
                if busy { ProgressView() }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
        .controlSize(.large)
        .disabled(busy)
    }

    // MARK: - Actions

    private func go(to next: Step) {
        withAnimation(.easeInOut(duration: 0.25)) { step = next }
    }

    private func finish() {
        withAnimation(.easeInOut) { hasSeenOnboarding = true }
    }

    /// Pounds where the region measures in them, kilograms elsewhere, unless the user has
    /// already chosen.
    private func defaultUnitFromRegion() {
        guard UserDefaults.standard.string(forKey: WeightFormatter.appStorageKey) == nil else { return }
        weightUnit = Locale.current.measurementSystem == .us ? WeightUnit.lbs.rawValue : WeightUnit.kg.rawValue
    }

    /// Moves on whatever the answer: the system prompt is the decision, and Settings can
    /// change it later.
    private func requestHealth() {
        healthRequestInProgress = true
        Task {
            try? await health.requestAuthorization()
            healthRequestInProgress = false
            go(to: .start)
        }
    }

    private func buildOwn() {
        let template = WorkoutTemplate(name: "New Program")
        modelContext.insert(template)
        do {
            try modelContext.save()
            builtTemplate = template
            templateToBuild = template
        } catch {
            PersistenceLogger.capture(error, operation: "create-template")
            modelContext.delete(template)
            errorMessage = PersistenceLogger.userMessage(prefix: "Could not create program", error: error)
        }
    }

    /// A program with exercises ends onboarding. One left empty is removed, so backing out
    /// returns to the choices without leaving a blank "New Program" behind.
    private func finishBuilding() {
        guard let template = builtTemplate else { return }
        builtTemplate = nil
        if template.exercises.isEmpty {
            modelContext.delete(template)
            do { try modelContext.save() } catch {
                PersistenceLogger.capture(error, operation: "delete-empty-template")
            }
        } else {
            finish()
        }
    }
}

// MARK: - Building blocks

/// Content that scrolls when it has to, with the step's buttons pinned to the bottom.
private struct StepLayout<Content: View, Actions: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xl) {
                content()
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                actions()
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.top, DesignTokens.Spacing.sm)
            .padding(.bottom, DesignTokens.Spacing.md)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

private struct StepHeader<Tint: ShapeStyle>: View {
    let icon: Image
    let tint: Tint
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            icon
                .icon(size: 44)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DesignTokens.Spacing.lg)
    }
}

/// One way to start: an icon, what it is, one line on what happens, and a chevron. Without
/// an action it is a plain card, for a start that is already done.
private struct StartOption: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: Image
    var iconTint: Color?
    let title: String
    let detail: String
    let action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { card }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
        } else {
            card
                .accessibilityElement(children: .combine)
        }
    }

    private var card: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            icon
                .icon(size: 26)
                .foregroundStyle(iconTint ?? DesignTokens.Common.primary(colorScheme))
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if action != nil {
                Ph.caretRight.regular
                    .icon(size: 16)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .contentShape(Rectangle())
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [WorkoutTemplate.self, Exercise.self], inMemory: true)
}
