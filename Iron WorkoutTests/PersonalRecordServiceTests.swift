//
//  PersonalRecordServiceTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
@testable import Iron_Workout

@Suite("PersonalRecordService")
struct PersonalRecordServiceTests {

    // MARK: - Builders

    private static func set(reps: Int, weight: Double, completed: Bool = true, type: SetType = .working) -> PerformedSet {
        let s = PerformedSet(
            setIndex: 0,
            targetReps: reps,
            actualReps: reps,
            targetWeight: weight,
            actualWeight: weight,
            isCompleted: completed
        )
        s.setType = type
        return s
    }

    private static func exercise(name: String, id: UUID = UUID(), sets: [PerformedSet]) -> WorkoutSessionExercise {
        let se = WorkoutSessionExercise(
            exerciseID: id,
            exerciseName: name,
            sortOrder: 0
        )
        for s in sets { s.sessionExercise = se; se.performedSets.append(s) }
        return se
    }

    private static func session(id: UUID = UUID(), startedAt: Date = .now, exercises: [WorkoutSessionExercise]) -> WorkoutSession {
        let session = WorkoutSession(id: id, templateName: "Test", startedAt: startedAt)
        session.completedSetCount = exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        for e in exercises {
            e.session = session
            session.exercises.append(e)
        }
        return session
    }

    // MARK: - Weight PR

    @Test("first-ever session produces weight PR with 'None' previous")
    func firstSessionProducesWeightPR() {
        let id = UUID()
        let current = Self.session(exercises: [
            Self.exercise(name: "Bench Press", id: id, sets: [Self.set(reps: 5, weight: 80)])
        ])

        let prs = PersonalRecordService.detectPersonalRecords(in: current, history: [])

        let weightPRs = prs.filter { $0.type == .weight }
        #expect(weightPRs.count == 1)
        #expect(weightPRs.first?.exerciseName == "Bench Press")
        #expect(weightPRs.first?.previousBest == "None")
        #expect(weightPRs.first?.value == "80 kg")
    }

    @Test("heavier current weight beats previous max and produces PR")
    func heavierWeightBeatsPrevious() {
        let id = UUID()
        let current = Self.session(exercises: [
            Self.exercise(name: "Squat", id: id, sets: [Self.set(reps: 5, weight: 100)])
        ])
        let history = [
            Self.session(exercises: [
                Self.exercise(name: "Squat", id: id, sets: [Self.set(reps: 5, weight: 90)])
            ])
        ]

        let prs = PersonalRecordService.detectPersonalRecords(in: current, history: history)

        let weightPRs = prs.filter { $0.type == .weight }
        #expect(weightPRs.count == 1)
        #expect(weightPRs.first?.value == "100 kg")
        #expect(weightPRs.first?.previousBest == "90 kg")
    }

    @Test("same max weight as history does not produce weight PR")
    func sameWeightNoPR() {
        let id = UUID()
        let current = Self.session(exercises: [
            Self.exercise(name: "Deadlift", id: id, sets: [Self.set(reps: 5, weight: 120)])
        ])
        let history = [
            Self.session(exercises: [
                Self.exercise(name: "Deadlift", id: id, sets: [Self.set(reps: 5, weight: 120)])
            ])
        ]

        let prs = PersonalRecordService.detectPersonalRecords(in: current, history: history)
        let weightPRs = prs.filter { $0.type == .weight }
        #expect(weightPRs.isEmpty)
    }

    // MARK: - Reps PR

    @Test("more reps at same weight produces reps PR")
    func moreRepsSameWeightProducesPR() {
        let id = UUID()
        let current = Self.session(exercises: [
            Self.exercise(name: "Overhead Press", id: id, sets: [Self.set(reps: 8, weight: 50)])
        ])
        let history = [
            Self.session(exercises: [
                Self.exercise(name: "Overhead Press", id: id, sets: [Self.set(reps: 6, weight: 50)])
            ])
        ]

        let prs = PersonalRecordService.detectPersonalRecords(in: current, history: history)
        let repsPRs = prs.filter { $0.type == .reps }
        #expect(repsPRs.count == 1)
        #expect(repsPRs.first?.value == "8 reps @ 50 kg")
        #expect(repsPRs.first?.previousBest == "6 reps")
    }

    @Test("same reps at same weight produces no reps PR")
    func sameRepsNoRepsPR() {
        let id = UUID()
        let current = Self.session(exercises: [
            Self.exercise(name: "Row", id: id, sets: [Self.set(reps: 8, weight: 60)])
        ])
        let history = [
            Self.session(exercises: [
                Self.exercise(name: "Row", id: id, sets: [Self.set(reps: 8, weight: 60)])
            ])
        ]

        let prs = PersonalRecordService.detectPersonalRecords(in: current, history: history)
        let repsPRs = prs.filter { $0.type == .reps }
        #expect(repsPRs.isEmpty)
    }

    @Test("regression — fewer reps than prior best at same-or-higher weight produces no PR")
    func regressionProducesNoPR() {
        // Current: 5 reps @ 70 kg
        // Previous: 10 reps @ 80 kg (heavier AND more reps)
        // previousBestReps at weight >= 70 = 10, current = 5. 5 > 10 is false → no PR.
        let id = UUID()
        let current = Self.session(exercises: [
            Self.exercise(name: "Bench", id: id, sets: [Self.set(reps: 5, weight: 70)])
        ])
        let history = [
            Self.session(exercises: [
                Self.exercise(name: "Bench", id: id, sets: [Self.set(reps: 10, weight: 80)])
            ])
        ]

        let prs = PersonalRecordService.detectPersonalRecords(in: current, history: history)
        let repsPRs = prs.filter { $0.type == .reps }
        #expect(repsPRs.isEmpty)
    }

    // MARK: - Edge cases

    @Test("exercise with no completed sets produces no PRs")
    func noCompletedSetsNoPRs() {
        let id = UUID()
        let current = Self.session(exercises: [
            Self.exercise(name: "Curl", id: id, sets: [Self.set(reps: 10, weight: 15, completed: false)])
        ])
        let prs = PersonalRecordService.detectPersonalRecords(in: current, history: [])
        #expect(prs.isEmpty)
    }

    @Test("non-working set (warmup, drop set) does not produce PR")
    func nonWorkingSetIgnored() {
        let id = UUID()
        let current = Self.session(exercises: [
            Self.exercise(name: "Bench", id: id, sets: [
                Self.set(reps: 5, weight: 100, type: .warmup)
            ])
        ])
        let prs = PersonalRecordService.detectPersonalRecords(in: current, history: [])
        #expect(prs.isEmpty)
    }

    @Test("current session is filtered out of history when passed in")
    func currentSessionNotConsideredHistory() {
        let id = UUID()
        let sessionID = UUID()
        let current = Self.session(id: sessionID, exercises: [
            Self.exercise(name: "Squat", id: id, sets: [Self.set(reps: 5, weight: 100)])
        ])

        // Pass same session as both current and in history. Should still detect weight PR
        // because currentSession is filtered by id.
        let prs = PersonalRecordService.detectPersonalRecords(in: current, history: [current])
        let weightPRs = prs.filter { $0.type == .weight }
        #expect(weightPRs.count == 1)
        #expect(weightPRs.first?.previousBest == "None")
    }

    @Test("exercise identity matches by ID across renamed snapshots")
    func identityMatchesAcrossRename() {
        // Historical session has snapshot "Old Name" but the same exerciseID.
        // Current session has snapshot "New Name" with the same exerciseID.
        // Should still recognize as the same exercise and produce weight PR only if
        // current weight exceeds historical.
        let exerciseID = UUID()
        let current = Self.session(exercises: [
            Self.exercise(name: "New Name", id: exerciseID, sets: [Self.set(reps: 5, weight: 105)])
        ])
        let history = [
            Self.session(exercises: [
                Self.exercise(name: "Old Name", id: exerciseID, sets: [Self.set(reps: 5, weight: 100)])
            ])
        ]

        let prs = PersonalRecordService.detectPersonalRecords(in: current, history: history)
        let weightPRs = prs.filter { $0.type == .weight }
        #expect(weightPRs.count == 1)
        #expect(weightPRs.first?.previousBest == "100 kg")
    }
}
