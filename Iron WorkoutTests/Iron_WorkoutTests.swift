//
//  Iron_WorkoutTests.swift
//  Anvil WorkoutTests
//
//  Test suites for Anvil Workout live in separate files per service:
//  - StreakCalculatorTests
//  - PersonalRecordServiceTests
//  - WorkoutSessionServiceTests
//
//  This file is intentionally kept as a placeholder so the Xcode target stays wired
//  up without pulling in Testing unnecessarily when no file lives here.
//

import Testing

@Suite("Anvil Workout")
struct IronWorkoutTestsSmokeSuite {
    @Test("test target loads")
    func targetLoads() {
        #expect(true)
    }
}
