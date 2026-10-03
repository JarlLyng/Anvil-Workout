//
//  ProgramRotation.swift
//  Anvil Workout
//
//  Which program the home screen offers next when nothing is planned for today.
//

import Foundation

/// What the rotation needs to know about a program. `WorkoutTemplate` has all three.
protocol RotationCandidate {
    var name: String { get }
    var sourceProgramID: String? { get }
    var createdAt: Date { get }
}

extension WorkoutTemplate: RotationCandidate {}

enum ProgramRotation {
    /// The program after the one last trained. Programs run in the order they were added,
    /// so a library program's workouts go A, B, A, and editing one does not reorder them.
    /// After a workout from a library program the next is its own next workout, not
    /// whatever was added after it. With no history, or a last workout whose program is
    /// gone, it is the first program added.
    static func next<T: RotationCandidate>(after lastTrainedName: String?, in programs: [T]) -> T? {
        let ordered = programs.sorted { ($0.createdAt, $0.name) < ($1.createdAt, $1.name) }
        guard let lastTrainedName, let last = ordered.first(where: { $0.name == lastTrainedName }) else {
            return ordered.first
        }
        let cycle = last.sourceProgramID.map { id in ordered.filter { $0.sourceProgramID == id } } ?? ordered
        guard let index = cycle.firstIndex(where: { $0.name == last.name }) else { return ordered.first }
        return cycle[(index + 1) % cycle.count]
    }
}
