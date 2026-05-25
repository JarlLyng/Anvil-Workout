//
//  AnvilWatchApp.swift
//  Anvil Watch
//
//  Entry point for the Apple Watch companion app. Owns a single
//  WatchConnectivityClient that mirrors snapshots from the iPhone.
//

import SwiftUI

@main
struct AnvilWatchApp: App {
    @State private var client = WatchConnectivityClient()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(client)
                .onAppear { client.activate() }
        }
    }
}
