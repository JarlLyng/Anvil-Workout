//
//  DiagnosticsServiceTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
import Sentry
@testable import Iron_Workout

@Suite("DiagnosticsService")
struct DiagnosticsServiceTests {

    /// A throwaway defaults domain, so the tests never touch the real switch.
    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "DiagnosticsServiceTests-\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    @Test("Crash reporting is on when the user has never touched the switch")
    func defaultsToEnabled() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        // Opt-out, not opt-in: existing installs keep reporting until someone turns it off.
        #expect(DiagnosticsService.isEnabled(in: defaults))
    }

    @Test("Turning the switch off is respected")
    func respectsOptOut() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(false, forKey: DiagnosticsService.preferenceKey)
        #expect(!DiagnosticsService.isEnabled(in: defaults))

        defaults.set(true, forKey: DiagnosticsService.preferenceKey)
        #expect(DiagnosticsService.isEnabled(in: defaults))
    }

    @Test(
        "Workout breadcrumbs carry no program or exercise names and no numbers",
        arguments: ["Workout started", "Set completed", "Workout ended"]
    )
    func workoutBreadcrumbsCarryNoData(message: String) {
        let crumb = DiagnosticsService.workoutBreadcrumb(message)

        #expect(crumb.category == "workout")
        #expect(crumb.message == message)
        // The privacy policy promises reports never include workout data. These three
        // breadcrumbs once carried program names, exercise names, set counts and duration;
        // this is the guard against that coming back.
        #expect(crumb.data == nil)
    }
}
