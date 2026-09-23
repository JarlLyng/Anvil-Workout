//
//  DiagnosticsService.swift
//  Anvil Workout
//
//  Everything the app sends to Sentry, and the user's switch to turn it off (#91).
//
//  Privacy-first (portfolio DNA): crash reporting only. Crash, hang and error reports,
//  and nothing else. No session tracking, no performance tracing on real users, no
//  screenshots or view hierarchy, and no workout names or numbers in breadcrumbs.
//
//  The privacy policy (docs/privacy.html) promises exactly what this file sends. Change
//  them together, and change the site only once the release carrying the change is live.
//

import Foundation
import Sentry

enum DiagnosticsService {

    /// UserDefaults key behind the Settings switch.
    static let preferenceKey = "crashReportingEnabled"

    /// Whether the user allows crash reporting. Unset means on: the switch is an opt-out,
    /// so existing installs keep reporting until someone turns it off.
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

    private static func start() {
        guard !SentrySDK.isEnabled, let dsn = SentryConfig.dsn else { return }
        SentrySDK.start { options in configure(options, dsn: dsn) }
    }

    /// `nonisolated` because Sentry calls the callbacks set here, such as `beforeSend`,
    /// from its own queues rather than the main actor.
    nonisolated private static func configure(_ options: Options, dsn: String) {
        options.dsn = dsn

        // Session tracking reports every launch, not only failures. Off everywhere: with a
        // small user base the individual report is the signal, not a crash-free rate.
        options.enableAutoSessionTracking = false

        // Client reports tell Sentry how many events the SDK discarded. They carry no user
        // data, but they are traffic that is not a crash report, and the privacy policy
        // says nothing is sent unless something goes wrong.
        options.sendClientReports = false

        #if DEBUG
        options.environment = "development"
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
        options.environment = "production"
        options.debug = false
        options.tracesSampleRate = 0
        #endif

        options.beforeSend = { event in
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
