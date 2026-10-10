//
//  FeedbackMailTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
@testable import Iron_Workout

@Suite("FeedbackMail")
struct FeedbackMailTests {

    private func mail() throws -> URLComponents {
        let url = try #require(FeedbackMail.url(appVersion: "1.10.1", build: "31", systemName: "iOS", systemVersion: "26.1"))
        return try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    }

    private func value(_ name: String, in components: URLComponents) -> String? {
        components.queryItems?.first { $0.name == name }?.value
    }

    @Test("Goes to the support address")
    func address() throws {
        let components = try mail()
        #expect(components.scheme == "mailto")
        #expect(components.path == "support@iamjarl.com")
    }

    @Test("The subject names the app and its version")
    func subject() throws {
        #expect(value("subject", in: try mail()) == "Anvil Workout 1.10.1 feedback")
    }

    @Test("The body leaves room to write, then gives the app and system versions")
    func body() throws {
        let body = try #require(value("body", in: try mail()))
        #expect(body.hasPrefix("\n\n"))
        #expect(body.hasSuffix("Anvil Workout 1.10.1 (31)\niOS 26.1"))
    }

    @Test("Spaces and line breaks are percent-encoded, so every mail app reads it the same")
    func encoded() throws {
        let url = try #require(FeedbackMail.url(appVersion: "1.10.1", build: "31", systemName: "iPadOS", systemVersion: "26.1"))
        #expect(!url.absoluteString.contains(" "))
        #expect(!url.absoluteString.contains("\n"))
        #expect(url.absoluteString.contains("%0A"))
    }
}
