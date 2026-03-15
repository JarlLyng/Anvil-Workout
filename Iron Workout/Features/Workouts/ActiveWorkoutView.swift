//
//  ActiveWorkoutView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    var onComplete: () -> Void
    var onEndWorkout: () -> Void

    @State private var currentExerciseIndex: Int = 0
    @State private var healthKitStarted = false
    @State private var restSecondsRemaining: Int?
    @State private var restTimer: Timer?
    @State private var showEndConfirm = false
    @State private var showSetEditor: PerformedSet?
    @State private var showCompletionSummary = false
    @State private var isPaused = false
    @State private var pausedAt: Date?
    @State private var totalPausedSeconds: Int = 0

    private var sortedExercises: [WorkoutSessionExercise] {
        session.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var currentExercise: WorkoutSessionExercise? {
        guard currentExerciseIndex >= 0, currentExerciseIndex < sortedExercises.count else { return nil }
        return sortedExercises[currentExerciseIndex]
    }

    private var currentSets: [PerformedSet] {
        currentExercise?.performedSets.sorted { $0.setIndex < $1.setIndex } ?? []
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
                            if let ex = currentExercise {
                                exerciseContent(exercise: ex)
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
                            if currentExercise != nil {
                                Button("Spring over øvelse", role: .destructive) { skipCurrentExercise() }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
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
                    try? modelContext.save()
                    showSetEditor = nil
                }
            }
            .onAppear {
                startHealthKitIfAvailable()
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
                Image(systemName: isPaused ? "pause.circle.fill" : "timer")
                    .foregroundStyle(isPaused ? .orange : .primary)
                Text(formatElapsed(elapsedSeconds(at: context.date)))
                    .font(.title2.monospacedDigit().weight(.medium))
                if isPaused {
                    Text("Pauset")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
            }
            .padding()
            .background(.bar)
        }
    }

    private var pauseOverlay: some View {
        VStack(spacing: 24) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
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
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.orange)
            Text("Rest: \(seconds) sek")
                .font(.headline.monospacedDigit())
            Spacer()
            Button("Næste sæt") {
                stopRestTimer()
                advanceToNextExerciseIfNeeded()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.orange.opacity(0.15))
    }

    private func exerciseContent(exercise: WorkoutSessionExercise) -> some View {
        let sets = currentSets
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(exercise.exerciseName)
                        .font(.title2.bold())
                    Spacer()
                    Button("Spring over øvelse") {
                        skipCurrentExercise()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Text("Sæt")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                ForEach(sets, id: \.id) { set in
                    setRow(set: set, exercise: exercise)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if currentExerciseIndex < sortedExercises.count - 1 {
                nextExercisePreview
            }
        }
    }

    private func setRow(set: PerformedSet, exercise: WorkoutSessionExercise) -> some View {
        let targetWeight = set.targetWeight.map { " @ \($0.formatted(.number.precision(.fractionLength(0)))) kg" } ?? ""
        return HStack {
            if set.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sæt \(set.setIndex + 1)")
                        .font(.subheadline.weight(.medium))
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
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                Text("Sæt \(set.setIndex + 1): \(set.targetReps) reps\(targetWeight)")
                    .font(.subheadline)
                Spacer()
                HStack(spacing: 8) {
                    Button("Skip") { markSetSkipped(set, exercise: exercise) }
                        .buttonStyle(.bordered)
                    Button("Færdig") { markSetDone(set, exercise: exercise) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var nextExercisePreview: some View {
        Group {
            if currentExerciseIndex + 1 < sortedExercises.count {
                let next = sortedExercises[currentExerciseIndex + 1]
                HStack {
                    Image(systemName: "arrow.down.circle")
                    Text("Næste: \(next.exerciseName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var completedAllView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
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
        set.isCompleted = true
        set.completedAt = .now
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        try? modelContext.save()
        startRestIfNeeded(exercise: exercise)
        if restSecondsRemaining == nil { advanceToNextExerciseIfNeeded() }
    }

    private func markSetSkipped(_ set: PerformedSet, exercise: WorkoutSessionExercise) {
        set.isCompleted = true
        set.completedAt = .now
        set.actualReps = nil
        set.actualWeight = nil
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        try? modelContext.save()
        startRestIfNeeded(exercise: exercise)
        if restSecondsRemaining == nil { advanceToNextExerciseIfNeeded() }
    }

    private func advanceToNextExerciseIfNeeded() {
        guard let ex = currentExercise else { return }
        let allDone = ex.performedSets.allSatisfy(\.isCompleted)
        if allDone, currentExerciseIndex < sortedExercises.count - 1 {
            currentExerciseIndex += 1
        }
    }

    private func skipCurrentExercise() {
        guard let ex = currentExercise else { return }
        stopRestTimer()
        for set in ex.performedSets where !set.isCompleted {
            set.isCompleted = true
            set.completedAt = .now
            set.actualReps = nil
            set.actualWeight = nil
        }
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        try? modelContext.save()
        if currentExerciseIndex < sortedExercises.count - 1 {
            currentExerciseIndex += 1
        }
    }

    private func pauseWorkout() {
        stopRestTimer()
        isPaused = true
        pausedAt = Date()
    }

    private func resumeWorkout() {
        if let start = pausedAt {
            totalPausedSeconds += Int(Date().timeIntervalSince(start).rounded())
        }
        pausedAt = nil
        isPaused = false
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
                advanceToNextExerciseIfNeeded()
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
                try? WorkoutSessionService.finalizeSession(session, modelContext: context)
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

