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
        // Everything fits on one screen down to the 40 mm watch (#98). The scroll view stays
        // for large accessibility text sizes, where it cannot fit.
        ScrollView {
            VStack(spacing: 6) {
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
            .padding(.horizontal, 4)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                elapsedTitle
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
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

    // MARK: - Elapsed time

    /// The workout clock, in the top bar left of the watch's own clock. A timer text counts
    /// by itself, and while paused it stands at the moment the pause began.
    private var elapsedTitle: Text {
        let from = snapshot.startedAt.addingTimeInterval(TimeInterval(snapshot.totalPausedSeconds))
        let clock = Text(timerInterval: from...Date.distantFuture, pauseTime: snapshot.pausedAt, countsDown: false)
        guard snapshot.pausedAt != nil else { return clock }
        return Text(Image(systemName: "pause.fill")) + Text(" ") + clock
    }

    // MARK: - Active set

    private func setBlock(exerciseName: String, setID: UUID) -> some View {
        VStack(spacing: 2) {
            Text(exerciseName)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("Set \(snapshot.currentSetNumber) of \(snapshot.totalSetsInExercise)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(targetLine)
                .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 2)

            HStack(spacing: 6) {
                Button {
                    client.send(.markSetSkipped(setID: setID))
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                // Done is the action taken on almost every set, so it is the bright one.
                Button {
                    client.send(.markSetDone(setID: setID))
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            }
            .padding(.top, 6)

            ProgressView(value: progressFraction)
                .tint(.accentColor)
                .padding(.top, 6)
                .accessibilityLabel("\(snapshot.completedSetCount) of \(snapshot.totalSetCount) sets done")
        }
    }

    /// Reps and weight for the pending set, as "5 × 102.5 kg". The weight text comes from the
    /// phone in the user's unit; a phone on an older build sends only kilograms.
    private var targetLine: String {
        let reps = snapshot.targetReps.map(String.init) ?? "–"
        if let weight = weightText {
            return "\(reps) × \(weight)"
        }
        return "\(reps) reps"
    }

    private var weightText: String? {
        if let text = snapshot.targetWeightText { return text }
        return snapshot.targetWeightKg.map { "\(formattedWeight($0)) kg" }
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
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.25), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(seconds) / CGFloat(max(total, 1)))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(seconds)")
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.orange)
                        .minimumScaleFactor(0.6)
                    // At zero with the phone locked, the watch has no next set to show until
                    // the phone wakes and sends one, so say the rest is over.
                    Text(seconds == 0 ? "Rest over" : "Rest")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            // 76 keeps the buttons below it on screen on the 40 mm watch.
            .frame(width: 76, height: 76)
            .accessibilityElement(children: .combine)

            // What comes after the rest is what you want to know during it. The phone sends
            // the next pending set in the snapshot even while resting.
            if snapshot.currentSetID != nil, snapshot.targetReps != nil {
                Text("Next  \(targetLine)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 6) {
                Button {
                    client.send(.addRestTime(seconds: 30))
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text("+30s").frame(maxWidth: .infinity)
                }
                Button {
                    client.send(.skipRest)
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text("Skip").frame(maxWidth: .infinity)
                }
                .tint(.orange)
            }
            .buttonStyle(.bordered)
            .padding(.top, 2)
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
