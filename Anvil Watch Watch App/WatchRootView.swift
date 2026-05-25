//
//  WatchRootView.swift
//  Anvil Watch
//
//  Routes between the idle screen ("start a workout on iPhone") and the
//  active workout screen based on whether the phone has broadcast a
//  snapshot. The watch never decides on its own — the phone is the source
//  of truth for whether a workout is in progress.
//

import SwiftUI

struct WatchRootView: View {
    @Environment(WatchConnectivityClient.self) private var client

    var body: some View {
        if let snapshot = client.snapshot {
            WatchActiveWorkoutView(snapshot: snapshot)
        } else {
            WatchIdleView(isReachable: client.isReachable)
        }
    }
}
