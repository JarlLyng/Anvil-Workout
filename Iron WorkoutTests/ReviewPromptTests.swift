//
//  ReviewPromptTests.swift
//  Anvil WorkoutTests
//

import Testing
@testable import Iron_Workout

@Suite("ReviewPrompt")
struct ReviewPromptTests {

    private func ask(_ count: Int, lastAsked: Int = 0, sets: Int = 15) -> Int? {
        ReviewPrompt.thresholdToAsk(after: .workoutCompleted(completedSets: sets), completedWorkouts: count, lastAsked: lastAsked)
    }

    @Test("Below the first threshold, nothing is asked")
    func belowFirst() {
        #expect(ask(4) == nil)
    }

    @Test("Each threshold asks when a workout reaches it", arguments: [(5, 0, 5), (15, 5, 15), (50, 15, 50)])
    func reachesThreshold(count: Int, lastAsked: Int, expected: Int) {
        #expect(ask(count, lastAsked: lastAsked) == expected)
    }

    @Test("A count that jumps past thresholds asks once, for the highest reached")
    func jumpAsksOnce() throws {
        // Imported history took the count from 0 to 212; the first workout after it asks.
        let first = ask(213)
        #expect(first == 50)
        // The next workout doesn't ask again.
        #expect(ask(214, lastAsked: try #require(first)) == nil)
    }

    @Test("A threshold already asked for doesn't ask again")
    func alreadyAsked() {
        #expect(ask(5, lastAsked: 5) == nil)
        #expect(ask(20, lastAsked: 15) == nil)
        #expect(ask(80, lastAsked: 50) == nil)
    }

    @Test("A count that drops back, say after deleting workouts, doesn't ask again on the way up")
    func dropsBack() {
        #expect(ask(14, lastAsked: 15) == nil)
        #expect(ask(15, lastAsked: 15) == nil)
    }

    @Test("An import on its own doesn't ask")
    func importDoesNotAsk() {
        #expect(ReviewPrompt.thresholdToAsk(after: .historyImported, completedWorkouts: 213, lastAsked: 0) == nil)
    }

    @Test("A workout that ended with no completed sets doesn't ask")
    func emptyWorkoutDoesNotAsk() {
        #expect(ask(5, sets: 0) == nil)
    }
}
