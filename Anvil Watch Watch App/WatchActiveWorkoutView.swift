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
//  countdown instead of the set actions, mirroring the phone UI. The countdown
//  runs from the rest's end date on the watch's own clock, so it keeps going
//  when the phone is locked and stops sending snapshots (#90).
//

import SwiftUI
import WatchKit

struct WatchActiveWorkoutView: View {
    @Environment(WatchConnectivityClient.self) private var client
    let snapshot: ActiveWorkoutSnapshot

    /// The rest end the watch has already tapped the wrist for, so the phone's later
    /// "rest over" snapshot does not tap a second time.
    @State private var tappedForRestEnd: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ElapsedTimerLine(snapshot: snapshot)

                Divider()

                if let endsAt = snapshot.restEndsAt {
                    // Count down locally. With the phone locked no new snapshot arrives,
                    // and the old per-second snapshots were the only thing that moved it.
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let seconds = RestCountdown.secondsRemaining(until: endsAt, at: context.date) ?? 0
                        restBlock(seconds: seconds, total: snapshot.restTotalSeconds ?? seconds)
                    }
                } else if let rest = snapshot.restSecondsRemaining {
                    // A phone on a build before #90 sends no end date; follow its seconds.
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
        .task(id: snapshot.restEndsAt) {
            // Tap the wrist when rest ends on the watch's own clock, without waiting for
            // the phone. This only fires while the watch app is running: with the wrist
            // lowered watchOS suspends it, and an on-time alert then needs a notification
            // (#89).
            guard let endsAt = snapshot.restEndsAt else { return }
            let wait = endsAt.timeIntervalSinceNow
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
            }
            guard !Task.isCancelled else { return }
            // Suspended past the end and only just woken: a late tap is noise, not a cue.
            guard Date().timeIntervalSince(endsAt) < 3 else { return }
            WKInterfaceDevice.current().play(.notification)
            tappedForRestEnd = endsAt
        }
        .onChange(of: snapshot.restSecondsRemaining) { oldValue, newValue in
            // Wrist tap when the phone reports the rest is over, matching the phone's
            // notification haptic. Skipped if the watch already tapped for this rest.
            if oldValue != nil && newValue == nil {
                if tappedForRestEnd == nil {
                    WKInterfaceDevice.current().play(.notification)
                }
                tappedForRestEnd = nil
            }
        }
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
            // At zero with the phone locked, the watch has no next set to show until the
            // phone wakes and sends one, so say the rest is over rather than showing 0s of rest.
            Text(seconds == 0 ? "Rest over" : "Rest")
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
