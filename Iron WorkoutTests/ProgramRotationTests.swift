//
//  ProgramRotationTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
@testable import Iron_Workout

@Suite("ProgramRotation")
struct ProgramRotationTests {

    private struct Program: RotationCandidate, Equatable {
        let name: String
        var sourceProgramID: String?
        let createdAt: Date
    }

    private static let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// Added in this order: a program of your own, then StrongLifts A and B.
    private static let programs = [
        Program(name: "Arms", sourceProgramID: nil, createdAt: start),
        Program(name: "StrongLifts 5×5 — Workout A", sourceProgramID: "stronglifts-5x5", createdAt: start.addingTimeInterval(60)),
        Program(name: "StrongLifts 5×5 — Workout B", sourceProgramID: "stronglifts-5x5", createdAt: start.addingTimeInterval(60.001)),
    ]

    @Test("With no history the first program added comes first, whatever order they arrive in")
    func firstAdded() {
        #expect(ProgramRotation.next(after: nil, in: Self.programs.reversed())?.name == "Arms")
        #expect(ProgramRotation.next(after: nil, in: Array(Self.programs.dropFirst()).reversed())?.name == "StrongLifts 5×5 — Workout A")
    }

    @Test("A library program alternates its own workouts")
    func libraryCycle() {
        #expect(ProgramRotation.next(after: "StrongLifts 5×5 — Workout A", in: Self.programs)?.name == "StrongLifts 5×5 — Workout B")
        #expect(ProgramRotation.next(after: "StrongLifts 5×5 — Workout B", in: Self.programs)?.name == "StrongLifts 5×5 — Workout A")
    }

    @Test("A program of your own is followed by the next program added")
    func ownPrograms() {
        #expect(ProgramRotation.next(after: "Arms", in: Self.programs)?.name == "StrongLifts 5×5 — Workout A")
    }

    @Test("A last workout whose program is gone starts from the first program")
    func deletedProgram() {
        #expect(ProgramRotation.next(after: "Legs", in: Self.programs)?.name == "Arms")
        #expect(ProgramRotation.next(after: "Legs", in: [Program]()) == nil)
    }
}
