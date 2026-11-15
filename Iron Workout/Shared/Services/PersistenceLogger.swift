//
//  PersistenceLogger.swift
//  Anvil Workout
//
//  Structured logging for SwiftData save/fetch failures. SwiftData wraps NSError
//  with codes that look identical in the default Sentry capture (e.g. "The file
//  couldn't be opened" with no domain or code visible). This helper extracts
//  domain/code/userInfo and attaches them as tags + extra so we can actually
//  diagnose intermittent failures users report.
//

import Foundation
import Sentry

enum PersistenceLogger {

    /// Captures an error from a SwiftData save/fetch with structured context. The
    /// `operation` string identifies the call site (e.g. "import-program",
    /// "create-template") so failures can be grouped per surface in Sentry. `extra` takes
    /// coarse facts only, never a name, a value or an ID from the user's data.
    static func capture(_ error: Error, operation: String, extra: [String: Any] = [:]) {
        let ns = error as NSError
        var data: [String: Any] = [
            "operation": operation,
            "domain": ns.domain,
            "code": ns.code,
            "localizedDescription": ns.localizedDescription
        ]
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            data["underlyingDomain"] = underlying.domain
            data["underlyingCode"] = underlying.code
            data["underlyingDescription"] = underlying.localizedDescription
        }
        // The file name only. The full path holds the app container's UUID, which is
        // different on every install, and no ID leaves the device (#129).
        if let path = ns.userInfo[NSFilePathErrorKey] as? String {
            data["fileName"] = URL(fileURLWithPath: path).lastPathComponent
        }
        for (key, value) in extra {
            data[key] = value
        }

        let crumb = Breadcrumb(level: .error, category: "persistence")
        crumb.message = "Persistence failure: \(operation)"
        for (key, value) in data {
            crumb.setData(value: value, key: key)
        }
        SentrySDK.addBreadcrumb(crumb)

        SentrySDK.capture(error: error) { scope in
            scope.setTag(value: operation, key: "persistence.operation")
            scope.setTag(value: ns.domain, key: "persistence.domain")
            scope.setTag(value: "\(ns.code)", key: "persistence.code")
            for (key, value) in data {
                scope.setExtra(value: value, key: key)
            }
        }
    }

    /// Builds a user-facing message that includes the NSError domain/code so support
    /// reports include actionable detail rather than just "the file couldn't be opened".
    static func userMessage(prefix: String, error: Error) -> String {
        let ns = error as NSError
        return "\(prefix): \(ns.localizedDescription) [\(ns.domain) #\(ns.code)]"
    }
}
