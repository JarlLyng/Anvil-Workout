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

@Suite("DiagnosticsService anonymizing")
struct DiagnosticsAnonymizingTests {

    @Test("Every event reports the shared user and loses the device ID and vendor-ID hash")
    func eventsAreAnonymous() {
        let event = Event()
        // What the SDK fills in when no user is set: a per-install ID.
        event.user = User(userId: "8C1F2D3E-0000-4000-8000-123456789ABC")
        event.context = [
            "app": ["device_app_hash": "abc123", "app_version": "1.10.1"],
            "device": ["id": "device-id", "model": "iPhone17,3"],
        ]

        DiagnosticsService.anonymize(event)

        #expect(event.user?.userId == "anonymous")
        #expect(event.context?["app"]?["device_app_hash"] == nil)
        #expect(event.context?["device"]?["id"] == nil)
        // Coarse facts stay, so a crash can still be read.
        #expect(event.context?["app"]?["app_version"] as? String == "1.10.1")
        #expect(event.context?["device"]?["model"] as? String == "iPhone17,3")
    }

    @Test("A transaction is anonymized the same way")
    func transactionsAreAnonymous() {
        let event: Event = Event()
        event.user = User(userId: "installation-id")
        event.context = ["app": ["device_app_hash": "abc123"]]

        DiagnosticsService.anonymize(event)

        #expect(event.user?.userId == "anonymous")
        #expect(event.context?["app"]?["device_app_hash"] == nil)
    }

    @Test("The per-install container UUID is replaced in stack frames, debug images and exception values")
    func containerPathsAreRedacted() {
        let installPath = "/private/var/containers/Bundle/Application/3F2504E0-4F89-11D3-9A0C-0305E82C3301/Iron Workout.app/Iron Workout"
        let fixedPath = "/private/var/containers/Bundle/Application/00000000-0000-0000-0000-000000000000/Iron Workout.app/Iron Workout"

        let frame = Frame()
        frame.package = installPath
        let exception = Exception(value: "Could not open /var/mobile/Containers/Data/Application/3F2504E0-4F89-11D3-9A0C-0305E82C3301/Library/default.store", type: "NSCocoaErrorDomain")
        exception.stacktrace = SentryStacktrace(frames: [frame], registers: [:])
        let image = DebugMeta()
        image.codeFile = installPath

        let event = Event()
        event.exceptions = [exception]
        event.debugMeta = [image]
        DiagnosticsService.anonymize(event)

        #expect(frame.package == fixedPath)
        #expect(image.codeFile == fixedPath)
        #expect(exception.value == "Could not open /var/mobile/Containers/Data/Application/00000000-0000-0000-0000-000000000000/Library/default.store")
        // A system framework's path has no container UUID and is left alone.
        #expect(DiagnosticsService.redactContainerPaths("/usr/lib/system/libdispatch.dylib") == "/usr/lib/system/libdispatch.dylib")
    }

    @Test("A count keeps only coarse facts and its source, never a user")
    func metricAttributesAreFiltered() {
        let attributes: [String: SentryAttributeContent] = [
            "user.id": .string("installation-id"),
            "user.email": .string("someone@example.com"),
            "sentry.replay_id": .string("replay"),
            "custom.anything": .string("value"),
            "source": .string("watch"),
            "sentry.release": .string("1.10.1"),
            "sentry.environment": .string("production"),
            "os.version": .string("27.1"),
            "device.model": .string("iPhone17,3"),
        ]

        let kept = DiagnosticsService.allowedAttributes(attributes)

        #expect(Set(kept.keys) == ["source", "sentry.release", "sentry.environment", "os.version", "device.model"])
    }

    @Test("The installation file holds the shared user, replacing a random ID")
    func installationIDIsPinned() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiagnosticsTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("INSTALLATION")

        // A fresh install: no directory yet.
        DiagnosticsService.pinInstallationID(cacheDirectoryPath: directory.path)
        #expect(try String(contentsOf: file, encoding: .utf8) == "anonymous")

        // An existing install, where the SDK already wrote a random ID.
        try Data(UUID().uuidString.utf8).write(to: file)
        DiagnosticsService.pinInstallationID(cacheDirectoryPath: directory.path)
        #expect(try String(contentsOf: file, encoding: .utf8) == "anonymous")
    }

    @Test("Test and simulator builds never report as production")
    func environmentIsNotProduction() {
        #expect(DiagnosticsService.environment == "development")
    }

    @Test("Counts do nothing when Sentry isn't running")
    func countsAreSilentWhenOff() {
        // In tests no DSN starts the SDK, as when the user has turned the switch off.
        #expect(!SentrySDK.isEnabled)
        DiagnosticsService.countWorkoutFinished()
        DiagnosticsService.countSetCompleted(from: .watch)
        DiagnosticsService.countImportFinished(from: .hevy)
    }
}
