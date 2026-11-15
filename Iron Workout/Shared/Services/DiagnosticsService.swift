//
//  DiagnosticsService.swift
//  Anvil Workout
//
//  Everything the app sends to Sentry, and the user's switch to turn it off (#91).
//
//  Anonymous diagnostics only (#129, #130): crash, hang and error reports, MetricKit's
//  diagnostics, crash-free sessions, and three counts of features being used. Anonymous
//  is a recipe, not Sentry's default. Out of the box sentry-cocoa sends a random
//  installation ID as the user, as every session's `did` and on every metric, plus a hash
//  of the vendor ID on every event. Everything below exists so that no ID leaves the
//  device: one shared user, `anonymous`, on every install.
//
//  No performance tracing on real users, no screenshots or view hierarchy in release
//  builds, and nothing from the user's own data: no program or exercise names, weights,
//  reps or notes, in breadcrumbs, events or counts.
//
//  The privacy policy (docs/privacy.html) and PrivacyInfo.xcprivacy promise exactly what
//  this file sends. Change them together, and change the site only once the release
//  carrying the change is live.
//

import Foundation
import Sentry

enum DiagnosticsService {

    /// UserDefaults key behind the Settings switch.
    /// A constant, read from the nonisolated `isEnabled(in:)` as well as the main actor.
    nonisolated static let preferenceKey = "crashReportingEnabled"

    /// Whether the user allows diagnostics. Unset means on: the switch is an opt-out, so
    /// existing installs keep reporting until someone turns it off. The key still says
    /// crash reporting because it predates the counts; one switch covers all of it.
    nonisolated static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: preferenceKey) as? Bool ?? true
    }

    /// Called once at launch. Starts Sentry only if a DSN is configured and the user has
    /// not turned reporting off.
    static func startIfAllowed() {
        guard isEnabled() else { return }
        start()
    }

    /// Applies the Settings switch straight away rather than at the next launch, so turning
    /// it off stops reporting in the session where the user made the choice.
    static func apply(enabled: Bool) {
        if enabled {
            start()
        } else if SentrySDK.isEnabled {
            SentrySDK.close()
        }
    }

    /// A breadcrumb for workout state changes. It deliberately carries no data: no program
    /// or exercise names and no counts, so a report says what the app was doing, not what
    /// the user was lifting.
    nonisolated static func workoutBreadcrumb(_ message: String) -> Breadcrumb {
        let crumb = Breadcrumb(level: .info, category: "workout")
        crumb.message = message
        return crumb
    }

    // MARK: - Feature counts

    /// Which device a set was logged from. Fixed values only.
    enum SetSource: String {
        case phone, watch
    }

    /// A finished workout, counted once it is saved. No program name, duration or volume.
    nonisolated static func countWorkoutFinished() {
        count("workout.finished")
    }

    /// A set marked done, with only the device it came from. No weight, reps or exercise.
    nonisolated static func countSetCompleted(from source: SetSource) {
        count("set.completed", source: source.rawValue)
    }

    /// An import from Strong or Hevy that was saved. Not how many workouts it held.
    nonisolated static func countImportFinished(from format: WorkoutCSVFormat) {
        count("import.finished", source: format == .strong ? "strong" : "hevy")
    }

    /// Does nothing when the switch is off or there is no DSN, because the SDK isn't running.
    nonisolated private static func count(_ name: String, source: String? = nil) {
        guard SentrySDK.isEnabled else { return }
        var attributes: [String: SentryAttributeValue] = [:]
        if let source { attributes[sourceAttribute] = source }
        SentrySDK.metrics.count(name, value: 1, options: SentryMetricOptions(attributes: attributes))
    }

    // MARK: - Anonymizing

    /// The one user every install reports as.
    nonisolated static let anonymousUser = "anonymous"

    /// The one attribute of our own a count may carry, always one of the fixed values above.
    nonisolated static let sourceAttribute = "source"

    /// The only attributes a metric may keep: the SDK's coarse facts (version, OS, device
    /// model) and ours. Anything else, `user.id` included, is dropped before sending.
    nonisolated static let allowedMetricAttributes: Set<String> = [
        "sentry.sdk.name", "sentry.sdk.version", "sentry.environment", "sentry.release",
        "os.name", "os.version", "device.brand", "device.model", "device.family",
        sourceAttribute,
    ]

    /// `production` only for App Store builds, so Debug, simulator and TestFlight runs are
    /// never read as real crashes. A TestFlight install carries a sandbox receipt.
    nonisolated static var environment: String {
        #if DEBUG || targetEnvironment(simulator)
        return "development"
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "testflight" : "production"
        #endif
    }

    /// For errors, crashes, MetricKit diagnostics and transactions: the shared user, no
    /// device ID or vendor-ID hash, and no per-install container path. The SDK fills in the
    /// installation ID as the user before this runs when no user is set, so the user is
    /// overwritten rather than checked.
    @discardableResult
    nonisolated static func anonymize(_ event: Event) -> Event {
        event.user = User(userId: anonymousUser)
        if var context = event.context {
            context["app"]?.removeValue(forKey: "device_app_hash")
            context["device"]?.removeValue(forKey: "id")
            event.context = context
        }

        let stacktraces = (event.threads ?? []).map(\.stacktrace)
            + (event.exceptions ?? []).map(\.stacktrace)
            + [event.stacktrace]
        for frame in stacktraces.compactMap({ $0 }).flatMap(\.frames) {
            if let package = frame.package { frame.package = redactContainerPaths(package) }
        }
        for image in event.debugMeta ?? [] {
            if let codeFile = image.codeFile { image.codeFile = redactContainerPaths(codeFile) }
        }
        for exception in event.exceptions ?? [] {
            if let value = exception.value { exception.value = redactContainerPaths(value) }
        }
        return event
    }

    /// The UUID that replaces the container's own in every path.
    nonisolated static let fixedContainerID = "00000000-0000-0000-0000-000000000000"

    /// The app's containers sit at `/var/containers/Bundle/Application/<UUID>/` and
    /// `/Data/Application/<UUID>/`, a UUID that differs on every install and changes with
    /// each update. Stack frames and debug images carry the bundle path, so the UUID is
    /// replaced with a fixed one. The rest of the path stays, so Sentry still recognises the
    /// app's own frames. Found in the envelope test (docs/dev/SETUP.md).
    nonisolated static func redactContainerPaths(_ text: String) -> String {
        text.replacingOccurrences(
            of: "/Application/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/",
            with: "/Application/\(fixedContainerID)/",
            options: .regularExpression
        )
    }

    nonisolated static func anonymize(_ metric: SentryMetric) -> SentryMetric {
        var metric = metric
        metric.attributes = allowedAttributes(metric.attributes)
        return metric
    }

    /// The metric attributes that may leave the device. Separate from `anonymize` so it can
    /// be tested: the SDK alone creates `SentryMetric` values.
    nonisolated static func allowedAttributes<Value>(_ attributes: [String: Value]) -> [String: Value] {
        attributes.filter { allowedMetricAttributes.contains($0.key) }
    }

    /// Sessions can't be given a user: sentry-cocoa sets every session's `did` from the
    /// INSTALLATION file in its cache directory, and writes a random UUID there when the file
    /// is missing. Writing the shared user into the file before the SDK starts makes every
    /// install report the same `did`. Checked against an outgoing session envelope with
    /// sentry-cocoa 9.34.0; check again after every SDK upgrade (docs/dev/SETUP.md).
    nonisolated static func pinInstallationID(cacheDirectoryPath: String) {
        let directory = URL(fileURLWithPath: cacheDirectoryPath)
        let url = directory.appendingPathComponent("INSTALLATION")
        let pinned = Data(anonymousUser.utf8)
        guard (try? Data(contentsOf: url)) != pinned else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? pinned.write(to: url, options: .atomic)
    }

    // MARK: - Starting

    /// The unit tests run inside the app, which would otherwise start Sentry with the
    /// developer's DSN on every test run and send sessions and counts from the test harness.
    nonisolated static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }

    private static func start() {
        guard !SentrySDK.isEnabled, !isRunningTests, let dsn = SentryConfig.dsn else { return }
        let options = Options()
        configure(options, dsn: dsn)
        pinInstallationID(cacheDirectoryPath: options.cacheDirectoryPath)
        SentrySDK.start(options: options)
    }

    /// `nonisolated` because Sentry calls the callbacks set here, such as `beforeSend`,
    /// from its own queues rather than the main actor.
    nonisolated private static func configure(_ options: Options, dsn: String) {
        options.dsn = dsn
        options.environment = environment

        // The shared user is on the scope before any integration starts, so no event,
        // crash report or metric falls back to the installation ID. beforeSend and
        // beforeSendMetric below make sure of it.
        options.initialScope = { scope in
            scope.setUser(User(userId: anonymousUser))
            return scope
        }
        options.sendDefaultPii = false

        // Crash-free sessions per version. A session carries a release, an environment,
        // a status and the pinned `did`, no installation ID (see pinInstallationID).
        options.enableAutoSessionTracking = true

        // Apple's own hang, CPU and disk-write diagnostics.
        options.enableMetricKit = true

        // Client reports tell Sentry how many events the SDK discarded. Not needed.
        options.sendClientReports = false

        #if DEBUG
        options.debug = true
        options.tracesSampleRate = 1.0
        options.attachScreenshot = true
        options.attachViewHierarchy = true
        // A paused debugger is indistinguishable from a hung main thread, so a Debug build
        // reports every breakpoint as an app hang. IOS-8 and IOS-9 were both that: an idle
        // CFRunLoop waiting in mach_msg with no app code on the stack. Production keeps
        // hang detection.
        options.enableAppHangTracking = false
        #else
        // No performance tracing on real users, and no screenshot or view hierarchy, which
        // can capture on-screen data.
        options.debug = false
        options.tracesSampleRate = 0
        options.attachScreenshot = false
        options.attachViewHierarchy = false
        #endif

        options.beforeSendMetric = { metric in anonymize(metric) }

        // In sentry-cocoa 9 transactions pass through beforeSend too (beforeSendTransaction
        // arrives in 10), so this one callback covers errors, crashes, MetricKit and traces.
        options.beforeSend = { event in
            anonymize(event)
            // Drop noise from auto-captured system NSErrors that aren't actionable.
            // Each entry below has a corresponding Sentry issue (IOS-N) we've
            // confirmed is not a bug but a system signal we can't act on.
            let noisyDomains: Set<String> = [
                // IOS-4: Guided Access blocking UIApplication.open
                "_UIViewServiceHostSessionErrorDomain",
                "FBSOpenApplicationServiceErrorDomain",
                "FBSOpenApplicationErrorDomain",
            ]
            if let exception = event.exceptions?.first,
               let type = exception.type {
                if noisyDomains.contains(type) {
                    return nil
                }
                // IOS-1: HealthKit code 11 = HKErrorAuthorizationDenied. Expected
                // user behaviour (declined permission), not a bug. We still want
                // other HealthKit errors (e.g. authorization changes mid-workout),
                // so we filter only code 11.
                if type == "com.apple.healthkit", exception.value == "Code: 11" {
                    return nil
                }
                // IOS-2: ActivityKit.ActivityAuthorization unsupportedTarget.
                // Means Live Activity isn't supported on the device or in the
                // current iOS region — nothing to fix in the app.
                if type == "com.apple.ActivityKit.ActivityAuthorization",
                   exception.value?.contains("unsupportedTarget") == true {
                    return nil
                }
                // IOS-6/IOS-7: WatchConnectivity errors on devices with no usable
                // watch — deviceNotPaired (7005), watchAppNotInstalled (7006),
                // notReachable (7007), deliveryFailed (7014). Expected, not bugs.
                // The send paths already guard on isPaired/isWatchAppInstalled;
                // this catches any that slip through (e.g. unpair mid-send).
                if type == "WCErrorDomain",
                   let value = exception.value,
                   ["Code: 7005", "Code: 7006", "Code: 7007", "Code: 7014"].contains(value) {
                    return nil
                }
            }
            return event
        }
    }
}
