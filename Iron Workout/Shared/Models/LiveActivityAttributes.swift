//
//  LiveActivityAttributes.swift
//  Iron Workout
//
//  Shared between main app and widget extension.
//  Remember to add this file to BOTH targets in Xcode (Target Membership).
//
//  Created by Jarl Lyng on 14/04/2026.
//

import ActivityKit
import Foundation

struct IronWorkoutWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentExercise: String
        var completedSets: Int
        var totalSets: Int
        var elapsedSeconds: Int
        var isPaused: Bool
    }

    var templateName: String
    var startedAt: Date
}
