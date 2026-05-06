//
//  SentryConfig.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation

enum SentryConfig {
    /// DSN is read from Info.plist (set via Secrets.xcconfig → build settings).
    /// See Config/Secrets.xcconfig.example for setup.
    static var dsn: String? {
        guard let value = Bundle.main.infoDictionary?["SENTRY_DSN"] as? String,
              !value.isEmpty, value != "YOUR_SENTRY_DSN_HERE" else {
            return nil
        }
        return value
    }
}
