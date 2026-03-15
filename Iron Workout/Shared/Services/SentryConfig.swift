//
//  SentryConfig.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation

enum SentryConfig {
    /// DSN læses fra Info.plist (sat via Secrets.xcconfig → build settings).
    /// Se Config/Secrets.xcconfig.example for opsætning.
    static var dsn: String? {
        guard let value = Bundle.main.infoDictionary?["SENTRY_DSN"] as? String,
              !value.isEmpty, value != "YOUR_SENTRY_DSN_HERE" else {
            return nil
        }
        return value
    }
}
