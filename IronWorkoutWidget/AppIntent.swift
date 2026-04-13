//
//  AppIntent.swift
//  IronWorkoutWidget
//
//  Created by Jarl Lyng on 14/04/2026.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Iron Workout Widget" }
    static var description: IntentDescription { "Vis din træningsstreak og ugens fremskridt." }
}
