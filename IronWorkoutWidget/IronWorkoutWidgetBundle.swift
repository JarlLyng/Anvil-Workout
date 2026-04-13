//
//  IronWorkoutWidgetBundle.swift
//  IronWorkoutWidget
//
//  Created by Jarl Lyng on 14/04/2026.
//

import WidgetKit
import SwiftUI

@main
struct IronWorkoutWidgetBundle: WidgetBundle {
    var body: some Widget {
        IronWorkoutWidget()
        IronWorkoutWidgetLiveActivity()
    }
}
