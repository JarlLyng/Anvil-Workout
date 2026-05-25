//
//  WatchConnectivityClient.swift
//  Anvil Watch
//
//  watchOS-side counterpart to WatchConnectivityService on iPhone.
//  Receives ActiveWorkoutSnapshot values via applicationContext and
//  exposes them as @Observable state for SwiftUI to render.
//
//  Sends WatchAction values back to the phone via sendMessage when
//  reachable, falling back to transferUserInfo so a tap on the watch
//  isn't lost when the phone is locked.
//

import Foundation
import WatchConnectivity

@Observable
@MainActor
final class WatchConnectivityClient: NSObject {
    /// Latest snapshot the phone sent, or nil if no workout is active.
    var snapshot: ActiveWorkoutSnapshot?

    /// True while the phone has explicitly told us the workout ended,
    /// or we've never received a snapshot.
    var isIdle: Bool { snapshot == nil }

    var isReachable: Bool = false

    private let delegateBridge = DelegateBridge()

    override init() {
        super.init()
        delegateBridge.client = self
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = delegateBridge
        if session.activationState != .activated {
            session.activate()
        }
        isReachable = session.isReachable
    }

    func send(_ action: WatchAction) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(action) else { return }
        let payload: [String: Any] = ["action": data]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                // Reachable but message failed — fall back to queued delivery.
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    fileprivate func receive(_ payload: [String: Any]) {
        if let endedFlag = payload["workoutEnded"] as? Bool, endedFlag {
            snapshot = nil
            return
        }
        if let data = payload["snapshot"] as? Data,
           let decoded = try? JSONDecoder().decode(ActiveWorkoutSnapshot.self, from: data) {
            snapshot = decoded
        }
    }

    fileprivate func setReachable(_ value: Bool) {
        isReachable = value
    }
}

/// WCSessionDelegate has to be a nonisolated NSObject; this bridge handles
/// the protocol conformance and hops back to the @MainActor client.
/// Explicit `nonisolated` overrides the watch target's default MainActor isolation.
private final class DelegateBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    nonisolated(unsafe) weak var client: WatchConnectivityClient?

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        let reachable = session.isReachable
        let context = session.receivedApplicationContext
        Task { @MainActor in
            client?.setReachable(reachable)
            client?.receive(context)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            client?.setReachable(reachable)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            client?.receive(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            client?.receive(message)
        }
    }
}
