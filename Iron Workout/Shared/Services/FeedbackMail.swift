//
//  FeedbackMail.swift
//  Anvil Workout
//
//  The "Send Feedback" email in Settings (#95). The app collects no usage data, so what
//  lifters choose to write is how their use of it is learned, and an unhappy one gets a
//  private route besides a public review. The email opens in the user's mail app with the
//  app and system version filled in, all of it visible before anything is sent.
//

import Foundation

enum FeedbackMail {
    /// The portfolio's one support address, the same as on the site.
    static let address = "support@iamjarl.com"

    /// `mailto:` to the support address, with the subject "Anvil Workout 1.10.1 feedback"
    /// and the versions at the end of the body, under room to write.
    static func url(appVersion: String, build: String, systemName: String, systemVersion: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Anvil Workout \(appVersion) feedback"),
            URLQueryItem(name: "body", value: "\n\n\n---\nAnvil Workout \(appVersion) (\(build))\n\(systemName) \(systemVersion)"),
        ]
        return components.url
    }
}
