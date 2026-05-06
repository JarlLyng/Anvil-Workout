//
//  AppIntent.swift
//  IronWorkoutWidget
//
//  Created by Jarl Lyng on 14/04/2026.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Anvil Workout Widget" }
    static var description: IntentDescription { "Show your workout streak and weekly progress." }
}
