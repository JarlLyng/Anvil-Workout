//
//  Iron_WorkoutTests.swift
//  Iron WorkoutTests
//
//  Test suites for Iron Workout live in separate files per service:
//  - StreakCalculatorTests
//  - PersonalRecordServiceTests
//  - WorkoutSessionServiceTests
//
//  This file is intentionally kept as a placeholder so the Xcode target stays wired
//  up without pulling in Testing unnecessarily when no file lives here.
//

import Testing

@Suite("Iron Workout")
struct IronWorkoutTestsSmokeSuite {
    @Test("test target loads")
    func targetLoads() {
        #expect(true)
    }
}
