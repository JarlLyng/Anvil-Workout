//
//  WatchContractsTests.swift
//  Anvil WorkoutTests
//
//  Guards the wire format shared between the iPhone app and the Apple Watch
//  companion (and the watch widget). The three WatchContracts.swift copies must
//  stay in lockstep; if a field is renamed or retyped on the phone without
//  updating the watch copies, encoding/decoding breaks silently in the gym.
//
//  Two layers of protection here:
//   1. Round-trip tests using the SAME default coders the transport uses
//      (WatchConnectivityService / WatchConnectivityClient both use plain
//      JSONEncoder()/JSONDecoder()), proving values survive a send/receive.
//   2. Frozen key-set tests that pin the exact JSON keys on the wire. These
//      fail the moment the phone contract drifts, which is the signal to apply
//      the same change to the watch copies.
//

import Testing
import Foundation
@testable import Iron_Workout

@Suite("WatchContracts")
struct WatchContractsTests {

    // The transport uses default coders on both ends; tests must match that.
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private func topLevelKeys(_ data: Data) throws -> Set<String> {
        let object = try JSONSerialization.jsonObject(with: data)
        let dict = try #require(object as? [String: Any])
        return Set(dict.keys)
    }

    // MARK: - Fixtures

    private func fullSnapshot() -> ActiveWorkoutSnapshot {
        ActiveWorkoutSnapshot(
            sessionID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            templateName: "Upper A",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalPausedSeconds: 42,
            pausedAt: Date(timeIntervalSince1970: 1_700_000_500),
            currentExerciseName: "Bench Press",
            currentSetNumber: 2,
            totalSetsInExercise: 5,
            targetReps: 8,
            targetWeightKg: 100,
            currentSetID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            restSecondsRemaining: 60,
            restTotalSeconds: 90,
            completedSetCount: 3,
            totalSetCount: 20
        )
    }

    private func minimalSnapshot() -> ActiveWorkoutSnapshot {
        ActiveWorkoutSnapshot(
            sessionID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            templateName: "Rest day check-in",
            startedAt: Date(timeIntervalSince1970: 1_700_100_000),
            totalPausedSeconds: 0,
            pausedAt: nil,
            currentExerciseName: nil,
            currentSetNumber: 1,
            totalSetsInExercise: 1,
            targetReps: nil,
            targetWeightKg: nil,
            currentSetID: nil,
            restSecondsRemaining: nil,
            restTotalSeconds: nil,
            completedSetCount: 0,
            totalSetCount: 0
        )
    }

    // MARK: - ActiveWorkoutSnapshot round-trip

    @Test("Snapshot with all fields survives encode/decode")
    func snapshotRoundTrip() throws {
        let original = fullSnapshot()
        let decoded = try decoder.decode(ActiveWorkoutSnapshot.self, from: encoder.encode(original))
        #expect(decoded == original)
    }

    @Test("Snapshot with all optionals nil survives encode/decode")
    func minimalSnapshotRoundTrip() throws {
        let original = minimalSnapshot()
        let decoded = try decoder.decode(ActiveWorkoutSnapshot.self, from: encoder.encode(original))
        #expect(decoded == original)
    }

    // MARK: - ActiveWorkoutSnapshot wire format

    @Test("Snapshot wire keys are frozen")
    func snapshotKeysAreFrozen() throws {
        // Renaming/removing any of these is a breaking change that must be
        // mirrored to the watch copies. Update this set deliberately, never casually.
        let expected: Set<String> = [
            "sessionID", "templateName", "startedAt", "totalPausedSeconds", "pausedAt",
            "currentExerciseName", "currentSetNumber", "totalSetsInExercise",
            "targetReps", "targetWeightKg", "currentSetID",
            "restSecondsRemaining", "restTotalSeconds",
            "completedSetCount", "totalSetCount",
        ]
        let keys = try topLevelKeys(encoder.encode(fullSnapshot()))
        #expect(keys == expected)
    }

    @Test("Nil optionals are omitted from the wire payload")
    func nilOptionalsOmitted() throws {
        let keys = try topLevelKeys(encoder.encode(minimalSnapshot()))
        #expect(!keys.contains("pausedAt"))
        #expect(!keys.contains("targetWeightKg"))
        #expect(!keys.contains("restSecondsRemaining"))
        // Required fields are still present.
        #expect(keys.contains("sessionID"))
        #expect(keys.contains("templateName"))
    }

    // MARK: - WatchStatsSnapshot

    @Test("Stats snapshot survives encode/decode")
    func statsRoundTrip() throws {
        let original = WatchStatsSnapshot(
            currentStreak: 7,
            totalWorkouts: 123,
            lastWorkoutName: "Leg Day",
            lastWorkoutDate: Date(timeIntervalSince1970: 1_700_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_200_100)
        )
        let decoded = try decoder.decode(WatchStatsSnapshot.self, from: encoder.encode(original))
        #expect(decoded == original)
    }

    @Test("Stats snapshot wire keys are frozen")
    func statsKeysAreFrozen() throws {
        let expected: Set<String> = [
            "currentStreak", "totalWorkouts", "lastWorkoutName", "lastWorkoutDate", "updatedAt",
        ]
        let original = WatchStatsSnapshot(
            currentStreak: 1, totalWorkouts: 1,
            lastWorkoutName: "X", lastWorkoutDate: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        let keys = try topLevelKeys(encoder.encode(original))
        #expect(keys == expected)
    }

    // MARK: - WatchAction

    @Test("Every WatchAction case survives encode/decode", arguments: [
        WatchAction.markSetDone(setID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!),
        WatchAction.markSetSkipped(setID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!),
        WatchAction.pause,
        WatchAction.resume,
        WatchAction.addRestTime(seconds: 30),
        WatchAction.skipRest,
    ])
    func actionRoundTrip(_ action: WatchAction) throws {
        let decoded = try decoder.decode(WatchAction.self, from: encoder.encode(action))
        #expect(decoded == action)
    }

    @Test("WatchAction case discriminators are frozen")
    func actionDiscriminatorsAreFrozen() throws {
        // Swift synthesizes enum-with-associated-values as { "<caseName>": { ... } }.
        // The watch routes on these case names, so they are part of the contract.
        func caseKey(_ action: WatchAction) throws -> String {
            let keys = try topLevelKeys(encoder.encode(action))
            return try #require(keys.first)
        }
        #expect(try caseKey(.markSetDone(setID: UUID())) == "markSetDone")
        #expect(try caseKey(.markSetSkipped(setID: UUID())) == "markSetSkipped")
        #expect(try caseKey(.pause) == "pause")
        #expect(try caseKey(.resume) == "resume")
        #expect(try caseKey(.addRestTime(seconds: 30)) == "addRestTime")
        #expect(try caseKey(.skipRest) == "skipRest")
    }

    @Test("WatchAction associated-value labels are frozen")
    func actionAssociatedValueLabels() throws {
        let doneData = try encoder.encode(WatchAction.markSetDone(setID: UUID()))
        let doneObject = try #require(try JSONSerialization.jsonObject(with: doneData) as? [String: Any])
        let donePayload = try #require(doneObject["markSetDone"] as? [String: Any])
        #expect(Set(donePayload.keys) == ["setID"])

        let restData = try encoder.encode(WatchAction.addRestTime(seconds: 45))
        let restObject = try #require(try JSONSerialization.jsonObject(with: restData) as? [String: Any])
        let restPayload = try #require(restObject["addRestTime"] as? [String: Any])
        #expect(Set(restPayload.keys) == ["seconds"])
    }
}
