//
//  ActiveWorkoutView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import UIKit
import IAMJARLDesignTokens
import PhosphorSwift

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var session: WorkoutSession
    var onComplete: () -> Void
    var onEndWorkout: () -> Void

    @State private var currentBlockIndex: Int = 0
    @State private var healthKitStarted = false
    @State private var restSecondsRemaining: Int?
    @State private var restTimer: Timer?
    @State private var showEndConfirm = false
    @State private var showSetEditor: PerformedSet?
    @State private var showCompletionSummary = false
    @State private var isPaused = false
    @State private var pausedAt: Date?
    @State private var totalPausedSeconds: Int = 0
    @State private var errorMessage: String?

    private var sortedExercises: [WorkoutSessionExercise] {
        session.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    private var exerciseBlocks: [[WorkoutSessionExercise]] {
        var blocks: [[WorkoutSessionExercise]] = []
        var currentBlock: [WorkoutSessionExercise] = []
        for ex in sortedExercises {
            if currentBlock.isEmpty {
                currentBlock.append(ex)
            } else {
                if let sid = ex.supersetID, sid == currentBlock.last?.supersetID {
                    currentBlock.append(ex)
                } else {
                    blocks.append(currentBlock)
                    currentBlock = [ex]
                }
            }
        }
        if !currentBlock.isEmpty {
            blocks.append(currentBlock)
        }
        return blocks
    }

    private var currentBlock: [WorkoutSessionExercise]? {
        let blocks = exerciseBlocks
        guard currentBlockIndex >= 0, currentBlockIndex < blocks.count else { return nil }
        return blocks[currentBlockIndex]
    }

    private func elapsedSeconds(at date: Date) -> Int {
        let total = Int(date.timeIntervalSince(session.startedAt).rounded())
        let extraPause: Int
        if isPaused, let start = pausedAt {
            extraPause = Int(date.timeIntervalSince(start).rounded())
        } else {
            extraPause = 0
        }
        return max(0, total - totalPausedSeconds - extraPause)
    }

    var body: some View {
        Group {
            if showCompletionSummary {
                WorkoutCompletionView(session: session) {
                    onEndWorkout()
                }
            } else {
                NavigationStack {
                    ZStack {
                        VStack(spacing: 0) {
                            timerBar
                            if let rest = restSecondsRemaining {
                                restBar(seconds: rest)
                            }
                            if let block = currentBlock {
                                blockContent(block: block)
                            } else {
                                completedAllView
                            }
                        }
                        if isPaused {
                            pauseOverlay
                        }
                    }
            .navigationTitle(session.templateName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Afslut") { showEndConfirm = true }
                }
                ToolbarItem(placement: .primaryAction) {
                    if isPaused {
                        Button("Fortsæt") { resumeWorkout() }
                    } else {
                        Menu {
                            Button("Pause træning") { pauseWorkout() }
                            if currentBlock != nil {
                                Button("Spring over nuværende", role: .destructive) { skipBlock() }
                            }
                        } label: {
                            Ph.dotsThreeCircle.regular
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .accessibilityLabel("Flere muligheder")
                        }
                    }
                }
            }
            .confirmationDialog("Afslut træning?", isPresented: $showEndConfirm, titleVisibility: .visible) {
                Button("Gem og afslut", role: .destructive) {
                    endWorkout()
                }
                Button("Fortsat", role: .cancel) { }
            } message: {
                Text("Træningen gemmes som den er. Du kan se den under Historik.")
            }
            .sheet(item: $showSetEditor) { set in
                EditPerformedSetSheet(performedSet: set) {
                    do { try modelContext.save() } catch { errorMessage = "Kunne ikke gemme: \(error.localizedDescription)" }
                    showSetEditor = nil
                }
            }
            .onAppear {
                startHealthKitIfAvailable()
            }
            .onDisappear {
                stopRestTimer()
            }
            .alert("Fejl", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
            }
        }
    }

    private func startHealthKitIfAvailable() {
        guard !healthKitStarted else { return }
        healthKitStarted = true
        Task {
            let health = HealthKitService.shared
            guard health.isAvailable else { return }
            try? await health.requestAuthorization()
            try? await health.startWorkout(startDate: session.startedAt)
        }
    }

    private var timerBar: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack {
                Group {
                    if isPaused {
                        Ph.pauseCircle.fill
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(DesignTokens.ColorToken.State.warning)
                    } else {
                        Ph.timer.regular
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }
                }
                Text(formatElapsed(elapsedSeconds(at: context.date)))
                    .font(.title2.monospacedDigit().weight(.medium))
                if isPaused {
                    Text("Pauset")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.ColorToken.State.warning)
                }
                Spacer()
            }
            .padding()
            .background(.bar)
        }
    }

    private var pauseOverlay: some View {
        VStack(spacing: 24) {
            Ph.pauseCircle.fill
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundStyle(DesignTokens.ColorToken.State.warning)
            Text("Træning sat på pause")
                .font(.title2.bold())
            Text("Timeren er stoppet. Tryk Fortsæt for at fortsætte.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Fortsæt træning") {
                resumeWorkout()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func restBar(seconds: Int) -> some View {
        HStack {
            Ph.pauseCircle.fill
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(DesignTokens.ColorToken.State.warning)
            Text("Rest: \(seconds) sek")
                .font(.headline.monospacedDigit())
            Spacer()
            Button("Næste") {
                stopRestTimer()
                advanceToNextBlockIfNeeded()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(DesignTokens.ColorToken.State.warning.opacity(0.15))
    }

    private func blockContent(block: [WorkoutSessionExercise]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if block.count > 1 {
                    HStack {
                        Ph.link.fill.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20).foregroundStyle(DesignTokens.ColorToken.State.warning)
                        Text("Supersæt").font(.headline).foregroundStyle(DesignTokens.ColorToken.State.warning)
                    }
                    .padding(.bottom, -12)
                }
                
                ForEach(block, id: \.id) { exercise in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(exercise.exerciseName)
                                .font(.title3.weight(.semibold))
                            Spacer()
                            Button("Spring over") {
                                skipExercise(exercise)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Spring \(exercise.exerciseName) over")
                        }

                        let sets = exercise.performedSets.sorted { $0.setIndex < $1.setIndex }
                        ForEach(sets, id: \.id) { set in
                            setRow(set: set, exercise: exercise)
                        }
                    }
                    if exercise.id != block.last?.id {
                        Divider().padding(.vertical, 8)
                    }
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if currentBlockIndex < exerciseBlocks.count - 1 {
                nextBlockPreview
            }
        }
    }

    private func colorForSetType(_ type: SetType) -> Color {
        switch type {
        case .working: return .primary
        case .warmup: return DesignTokens.ColorToken.State.warning
        case .drop: return DesignTokens.Common.primary(colorScheme)
        case .failure: return DesignTokens.ColorToken.State.error
        }
    }

    private func setRow(set: PerformedSet, exercise: WorkoutSessionExercise) -> some View {
        let targetWeight = set.targetWeight.map { " @ \($0.formatted(.number.precision(.fractionLength(0)))) kg" } ?? ""
        return HStack {
            if set.isCompleted {
                Ph.checkCircle.fill
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(DesignTokens.ColorToken.State.success)
                    .transition(.scale.combined(with: .opacity))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Sæt \(set.setIndex + 1)")
                            .font(.subheadline.weight(.medium))
                        if set.setType != .working {
                            Text("(\(set.setType.rawValue))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(colorForSetType(set.setType))
                        }
                    }
                    if let reps = set.actualReps {
                        Text("\(reps) reps\(set.actualWeight.map { " · \($0.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Rediger") { showSetEditor = set }
                    .font(.caption)
            } else {
                Ph.circle.regular
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.secondary)
                    
                VStack(alignment: .leading, spacing: 2) {
                    Menu {
                        ForEach(SetType.allCases, id: \.self) { type in
                            Button(type.rawValue) {
                                withAnimation { set.setType = type }
                                do { try modelContext.save() } catch { errorMessage = "Fejl: \(error)" }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Sæt \(set.setIndex + 1)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if set.setType != .working {
                                Text("(\(set.setType.rawValue))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(colorForSetType(set.setType))
                            }
                            Ph.caretDown.regular
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text("\(set.targetReps) reps\(targetWeight)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button("Skip") { markSetSkipped(set, exercise: exercise) }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    Button("Færdig") { markSetDone(set, exercise: exercise) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }

    private var nextBlockPreview: some View {
        Group {
            if currentBlockIndex + 1 < exerciseBlocks.count {
                let nextBlock = exerciseBlocks[currentBlockIndex + 1]
                let names = nextBlock.map(\.exerciseName).joined(separator: " + ")
                HStack {
                    Ph.arrowCircleDown.regular
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                    Text("Næste: \(names)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var completedAllView: some View {
        VStack(spacing: 24) {
            Spacer()
            Ph.checkCircle.fill
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundStyle(DesignTokens.ColorToken.State.success)
            Text("Alle øvelser gennemført")
                .font(.title2.bold())
            Text("\(session.completedSetCount) sæt i alt")
                .foregroundStyle(.secondary)
            Button("Afslut træning") { endWorkout() }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            Spacer()
        }
    }

    private func markSetDone(_ set: PerformedSet, exercise: WorkoutSessionExercise) {
        if set.actualReps == nil { set.actualReps = set.targetReps }
        if set.actualWeight == nil { set.actualWeight = set.targetWeight }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            set.isCompleted = true
        }
        set.completedAt = .now
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        do { try modelContext.save() } catch { errorMessage = "Kunne ikke gemme: \(error.localizedDescription)" }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        startRestIfNeeded(exercise: exercise)
        if restSecondsRemaining == nil { advanceToNextBlockIfNeeded() }
    }

    private func markSetSkipped(_ set: PerformedSet, exercise: WorkoutSessionExercise) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            set.isCompleted = true
        }
        set.completedAt = .now
        set.actualReps = nil
        set.actualWeight = nil
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        do { try modelContext.save() } catch { errorMessage = "Kunne ikke gemme: \(error.localizedDescription)" }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        startRestIfNeeded(exercise: exercise)
        if restSecondsRemaining == nil { advanceToNextBlockIfNeeded() }
    }

    private func advanceToNextBlockIfNeeded() {
        guard let block = currentBlock else { return }
        let allDone = block.allSatisfy { $0.performedSets.allSatisfy(\.isCompleted) }
        if allDone, currentBlockIndex < exerciseBlocks.count - 1 {
            currentBlockIndex += 1
        }
    }

    private func skipBlock() {
        guard let block = currentBlock else { return }
        stopRestTimer()
        for ex in block {
            for set in ex.performedSets where !set.isCompleted {
                set.isCompleted = true
                set.completedAt = .now
                set.actualReps = nil
                set.actualWeight = nil
            }
        }
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        do { try modelContext.save() } catch { errorMessage = "Fejl: \(error)" }
        if currentBlockIndex < exerciseBlocks.count - 1 {
            currentBlockIndex += 1
        }
    }

    private func skipExercise(_ exercise: WorkoutSessionExercise) {
        for set in exercise.performedSets where !set.isCompleted {
            set.isCompleted = true
            set.completedAt = .now
            set.actualReps = nil
            set.actualWeight = nil
        }
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        do { try modelContext.save() } catch { errorMessage = "Fejl: \(error)" }
        advanceToNextBlockIfNeeded()
    }

    private func pauseWorkout() {
        stopRestTimer()
        isPaused = true
        pausedAt = Date()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    private func resumeWorkout() {
        if let start = pausedAt {
            totalPausedSeconds += Int(Date().timeIntervalSince(start).rounded())
        }
        pausedAt = nil
        isPaused = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func startRestIfNeeded(exercise: WorkoutSessionExercise) {
        guard let rest = exercise.restSeconds, rest > 0 else { return }
        restSecondsRemaining = rest
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard var r = restSecondsRemaining else { return }
            r -= 1
            restSecondsRemaining = r <= 0 ? nil : r
            if restSecondsRemaining == nil {
                restTimer?.invalidate()
                restTimer = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                advanceToNextBlockIfNeeded()
            }
        }
        RunLoop.main.add(restTimer!, forMode: .common)
    }

    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restSecondsRemaining = nil
    }

    private func endWorkout() {
        stopRestTimer()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let context = modelContext
        Task {
            let health = HealthKitService.shared
            if health.isAvailable, let result = try? await health.endWorkout(endDate: Date()) {
                await MainActor.run {
                    session.calories = result.calories
                    session.averageHeartRate = result.averageHeartRate
                }
            }
            await MainActor.run {
                do { try WorkoutSessionService.finalizeSession(session, modelContext: context) } catch { errorMessage = "Kunne ikke afslutte træning: \(error.localizedDescription)" }
                showCompletionSummary = true
            }
        }
    }

    private func formatElapsed(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
