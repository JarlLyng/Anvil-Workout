//
//  WatchConnectivityService.swift
//  Anvil Workout
//
//  iPhone-side WatchConnectivity wrapper. Owns a single WCSession,
//  broadcasts ActiveWorkoutSnapshot via updateApplicationContext, and
//  receives WatchAction messages from the paired Apple Watch.
//
//  Resilience choices:
//  - applicationContext is used for snapshots (the latest one wins, queued
//    when watch is unreachable). Actions from the watch use sendMessage
//    when reachable with a transferUserInfo fallback for delivery guarantees.
//  - The service is a no-op on devices where WCSession.isSupported is false
//    (iPad, simulators without paired watch).
//

import Foundation
import Sentry
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

@Observable
@MainActor
final class WatchConnectivityService {
    static let shared = WatchConnectivityService()

    /// Set by the active workout view so we can route incoming actions.
    var actionHandler: ((WatchAction) -> Void)?

    private(set) var isWatchReachable: Bool = false
    private(set) var isWatchPaired: Bool = false

    #if canImport(WatchConnectivity)
    private let delegateBridge = DelegateBridge()
    #endif

    private init() {
        #if canImport(WatchConnectivity)
        delegateBridge.service = self
        activateIfSupported()
        #endif
    }

    #if canImport(WatchConnectivity)
    private func activateIfSupported() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = delegateBridge
        session.activate()
    }
    #endif

    #if canImport(WatchConnectivity)
    /// Returns the session only when a watch can actually receive application-context
    /// updates: supported, activated, paired, and running our watch app. Without the
    /// isPaired/isWatchAppInstalled guards, `updateApplicationContext` throws on the
    /// many devices with no watch, producing WCError deviceNotPaired (7005) /
    /// watchAppNotInstalled (7006) noise for something entirely expected.
    private func sessionReadyForWatchApp() -> WCSession? {
        guard WCSession.isSupported() else { return nil }
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else { return nil }
        return session
    }
    #endif

    /// Push a snapshot of the active workout to the watch. Safe to call frequently —
    /// applicationContext coalesces to the latest value.
    func sendSnapshot(_ snapshot: ActiveWorkoutSnapshot) {
        #if canImport(WatchConnectivity)
        guard let session = sessionReadyForWatchApp() else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try session.updateApplicationContext(["snapshot": data])
        } catch {
            SentrySDK.capture(error: error)
        }
        #endif
    }

    /// Push a stats snapshot (streak, last workout) to the watch so its widget
    /// has fresh data even when no workout is running.
    func sendStats(_ stats: WatchStatsSnapshot) {
        #if canImport(WatchConnectivity)
        guard let session = sessionReadyForWatchApp() else { return }
        do {
            let data = try JSONEncoder().encode(stats)
            // Coalesce with any in-flight snapshot via a dedicated key.
            var context = session.applicationContext
            context["stats"] = data
            try session.updateApplicationContext(context)
        } catch {
            SentrySDK.capture(error: error)
        }
        #endif
    }

    /// Tell the watch the workout has ended — clears its UI back to the idle screen.
    func sendWorkoutEnded() {
        #if canImport(WatchConnectivity)
        guard let session = sessionReadyForWatchApp() else { return }
        do {
            try session.updateApplicationContext(["workoutEnded": true])
        } catch {
            SentrySDK.capture(error: error)
        }
        #endif
    }

    fileprivate func setReachability(reachable: Bool, paired: Bool) {
        self.isWatchReachable = reachable
        self.isWatchPaired = paired
    }

    fileprivate func handleAction(_ data: Data) {
        do {
            let action = try JSONDecoder().decode(WatchAction.self, from: data)
            self.actionHandler?(action)
        } catch {
            SentrySDK.capture(error: error)
        }
    }
}

#if canImport(WatchConnectivity)
/// WCSessionDelegate has to be a nonisolated NSObject. The bridge converts
/// nonisolated callbacks into MainActor work on the service.
private final class DelegateBridge: NSObject, WCSessionDelegate {
    weak var service: WatchConnectivityService?

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error {
            SentrySDK.capture(error: error)
        }
        let reachable = session.isReachable
        let paired = session.isPaired
        Task { @MainActor in
            service?.setReachability(reachable: reachable, paired: paired)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Required on iPhone-side; re-activate so a new paired watch can connect.
        Task { @MainActor in
            WCSession.default.activate()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        let paired = session.isPaired
        Task { @MainActor in
            service?.setReachability(reachable: reachable, paired: paired)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        forwardAction(in: message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        forwardAction(in: message)
        replyHandler(["ok": true])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        forwardAction(in: userInfo)
    }

    private func forwardAction(in payload: [String: Any]) {
        guard let data = payload["action"] as? Data else { return }
        Task { @MainActor in
            service?.handleAction(data)
        }
    }
}
#endif
