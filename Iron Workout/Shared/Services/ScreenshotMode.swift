//
//  ScreenshotMode.swift
//  Anvil Workout
//
//  Debug builds only. The portfolio's capture pattern for App Store screenshots (DESIGN.md
//  in the strategy hub): `-screenshots` fills an empty store with demo history, skips
//  onboarding and every permission prompt, and `-screen <name>` opens one screen, so each
//  capture comes out the same every time:
//
//    xcrun simctl launch <device> com.iamjarl.Iron-Workout -screenshots -screen stats
//
//  Add `-weightUnit lbs` for a set in pounds; the demo history is then built in round
//  pound steps rather than converted kilograms.
//

#if DEBUG
import Foundation

enum ScreenshotMode {
    enum Screen: String {
        case home, workout, stats, completion, history, library, onboarding, programs, exercises
    }

    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-screenshots") }

    /// The screen named after `-screen`, when screenshot mode is on.
    static var screen: Screen? {
        let arguments = ProcessInfo.processInfo.arguments
        guard isOn, let index = arguments.firstIndex(of: "-screen"), index + 1 < arguments.count else { return nil }
        return Screen(rawValue: arguments[index + 1])
    }

    /// For the site's hero loop (#110): `-siteAutoDone 1.5` marks the workout screen's current
    /// set done that many seconds after it opens, as a tap on Done would, so the rest timer
    /// starting and the next set coming up can be recorded without a hand on the simulator.
    static var autoDoneDelay: Double? {
        let arguments = ProcessInfo.processInfo.arguments
        guard isOn, let index = arguments.firstIndex(of: "-siteAutoDone"), index + 1 < arguments.count else { return nil }
        return Double(arguments[index + 1])
    }

    /// Where a screen starts scrolled to, from `-siteScroll`: `records` puts Stats' records and
    /// estimated one-rep max on screen, for the site's tour (#110).
    static var scrollTarget: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard isOn, let index = arguments.firstIndex(of: "-siteScroll"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// Settles what the views read at launch. Called from the app's `init`, before any view.
    static func prepare() {
        guard isOn else { return }
        UserDefaults.standard.set(screen != .onboarding, forKey: "hasSeenOnboarding")
    }
}
#endif
