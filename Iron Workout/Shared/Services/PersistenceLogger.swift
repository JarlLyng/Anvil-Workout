//
//  PersistenceLogger.swift
//  Iron Workout
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
    /// "create-template") so failures can be grouped per surface in Sentry.
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
        if let path = ns.userInfo[NSFilePathErrorKey] as? String {
            data["filePath"] = path
        }
        for (key, value) in extra {
            data[key] = value
        }

        let crumb = Breadcrumb(level: .error, category: "persistence")
        crumb.message = "Persistence failure: \(operation)"
        crumb.data = data
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
