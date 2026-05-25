//
//  WatchRootView.swift
//  Anvil Watch
//
//  P1 minimal: shows connection status and the latest received snapshot's
//  template name so we can verify the WatchConnectivity handshake works
//  end-to-end. P2 will replace this with the real active-workout UI.
//

import SwiftUI

struct WatchRootView: View {
    @Environment(WatchConnectivityClient.self) private var client

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Circle()
                    .fill(client.isReachable ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(client.isReachable ? "Connected" : "Waiting")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let snapshot = client.snapshot {
                Text(snapshot.templateName)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let exercise = snapshot.currentExerciseName {
                    Text(exercise)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text("\(snapshot.completedSetCount) / \(snapshot.totalSetCount) sets")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "dumbbell.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Start a workout on iPhone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}
