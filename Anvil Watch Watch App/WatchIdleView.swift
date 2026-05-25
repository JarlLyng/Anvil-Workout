//
//  WatchIdleView.swift
//  Anvil Watch
//
//  Shown when no workout is active on the phone. Watch can't start a
//  workout on its own in P2 (that's a future enhancement) — it directs
//  the user to the phone.
//

import SwiftUI

struct WatchIdleView: View {
    let isReachable: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.title)
                .foregroundStyle(.secondary)

            Text("No workout running")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(isReachable
                 ? "Start a workout on iPhone to track it here."
                 : "Bring your iPhone closer to connect.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Circle()
                    .fill(isReachable ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text(isReachable ? "Connected" : "Waiting")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
        }
        .padding()
    }
}
