//
//  WatchActiveWorkoutView.swift
//  Anvil Watch
//
//  The watch's primary screen during a workout. Renders directly from
//  the phone-provided snapshot — no local state, no editing. Done/Skip
//  buttons send WatchAction back to the phone, which mutates the SwiftData
//  session there.
//
//  When a rest timer is running on the phone, this view swaps to the rest
//  countdown instead of the set actions, mirroring the phone UI.
//

import SwiftUI
import WatchKit

struct WatchActiveWorkoutView: View {
    @Environment(WatchConnectivityClient.self) private var client
    let snapshot: ActiveWorkoutSnapshot

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ElapsedTimerLine(snapshot: snapshot)

                Divider()

                if let rest = snapshot.restSecondsRemaining {
                    restBlock(seconds: rest, total: snapshot.restTotalSeconds ?? rest)
                } else if let exerciseName = snapshot.currentExerciseName,
                          let setID = snapshot.currentSetID {
                    setBlock(exerciseName: exerciseName, setID: setID)
                } else {
                    allDoneBlock
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle(snapshot.templateName)
    }

    // MARK: - Active set

    private func setBlock(exerciseName: String, setID: UUID) -> some View {
        VStack(spacing: 6) {
            Text(exerciseName)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text("Set \(snapshot.currentSetNumber) of \(snapshot.totalSetsInExercise)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(targetLine)
                .font(.title3.bold().monospacedDigit())
                .padding(.top, 2)

            HStack(spacing: 8) {
                Button {
                    client.send(.markSetSkipped(setID: setID))
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                }
                .tint(.secondary)

                Button {
                    client.send(.markSetDone(setID: setID))
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .tint(.accentColor)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 6)

            ProgressView(value: progressFraction)
                .tint(.accentColor)
                .padding(.top, 4)
            Text("\(snapshot.completedSetCount) / \(snapshot.totalSetCount) sets")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var targetLine: String {
        let reps = snapshot.targetReps.map { "\($0) reps" } ?? "—"
        if let kg = snapshot.targetWeightKg {
            return "\(reps) × \(formattedWeight(kg)) kg"
        }
        return reps
    }

    private func formattedWeight(_ kg: Double) -> String {
        if kg.rounded() == kg {
            return String(Int(kg))
        }
        return String(format: "%.1f", kg)
    }

    private var progressFraction: Double {
        guard snapshot.totalSetCount > 0 else { return 0 }
        return Double(snapshot.completedSetCount) / Double(snapshot.totalSetCount)
    }

    // MARK: - Rest timer

    private func restBlock(seconds: Int, total: Int) -> some View {
        VStack(spacing: 8) {
            Text("Rest")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(seconds)s")
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.orange)

            ProgressView(value: Double(seconds), total: Double(max(total, 1)))
                .tint(.orange)
                .padding(.horizontal, 8)

            HStack(spacing: 8) {
                Button("+30s") {
                    client.send(.addRestTime(seconds: 30))
                    WKInterfaceDevice.current().play(.click)
                }
                Button("Skip") {
                    client.send(.skipRest)
                    WKInterfaceDevice.current().play(.click)
                }
                .tint(.orange)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
    }

    // MARK: - All done

    private var allDoneBlock: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("All sets done")
                .font(.headline)
            Text("End the workout on iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Elapsed timer line

/// Renders the running elapsed time using a TimelineView so it ticks
/// every second without the phone having to push fresh snapshots.
private struct ElapsedTimerLine: View {
    let snapshot: ActiveWorkoutSnapshot

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 4) {
                Image(systemName: snapshot.pausedAt == nil ? "timer" : "pause.circle.fill")
                    .foregroundStyle(snapshot.pausedAt == nil ? Color.secondary : Color.orange)
                Text(formatElapsed(elapsed(at: context.date)))
                    .font(.title3.monospacedDigit().weight(.medium))
                if snapshot.pausedAt != nil {
                    Text("Paused")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func elapsed(at date: Date) -> Int {
        let total = Int(date.timeIntervalSince(snapshot.startedAt).rounded())
        let extraPause: Int
        if let pausedAt = snapshot.pausedAt {
            extraPause = Int(date.timeIntervalSince(pausedAt).rounded())
        } else {
            extraPause = 0
        }
        return max(0, total - snapshot.totalPausedSeconds - extraPause)
    }

    private func formatElapsed(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
