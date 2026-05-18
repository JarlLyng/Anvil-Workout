//
//  ProgramShareService.swift
//  Anvil Workout
//
//  Encodes a WorkoutTemplate into a compact universal-link URL and decodes it back.
//  The encoded payload travels in the URL path, base64URL-encoded, so the entire
//  program fits in a single SMS message for typical workouts (5-8 exercises).
//
//  No backend — the URL itself carries the program data. Recipient's app decodes
//  it locally on universal-link tap.
//

import Foundation
import SwiftData

enum ProgramShareError: Error, LocalizedError {
    case invalidURL
    case decodeFailed
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The link doesn't look like a valid Anvil Workout program link."
        case .decodeFailed: return "Couldn't read the program data from the link."
        case .unsupportedVersion(let v): return "This link was created by a newer version of Anvil Workout (format v\(v)). Update the app and try again."
        }
    }
}

/// On-the-wire program payload. Exercises are referenced by name so the recipient
/// can match against their local exercise library. Unknown names are imported
/// anyway — we create a placeholder Exercise so the program is usable.
struct SharedProgramPayload: Codable {
    /// Format version. Bump if the shape changes incompatibly. Decoder rejects
    /// versions it doesn't understand.
    let v: Int
    let name: String
    let note: String?
    let exercises: [SharedExercisePayload]
}

struct SharedExercisePayload: Codable {
    /// Exercise name. Matched against the recipient's Exercise library on import.
    let name: String
    /// Target sets.
    let s: Int
    /// Target reps.
    let r: Int
    /// Target weight in kg. Optional — bodyweight exercises don't have one.
    let w: Double?
    /// Rest seconds.
    let rs: Int?
    /// Per-exercise notes.
    let n: String?
    /// Superset group ID. Two exercises with the same supersetID are paired in active workout.
    let sup: String?
}

enum ProgramShareService {

    /// Current encoding version. Bump only for breaking changes; additive fields
    /// can be made optional in `SharedExercisePayload` without bumping.
    private static let currentVersion = 1

    /// Domain hosting the universal link and the website fallback page.
    static let host = "anvilworkout.iamjarl.com"

    /// URL path prefix that the AASA file maps to the app. Anything under `/p/`
    /// opens the import flow.
    private static let pathPrefix = "/p/"

    // MARK: - Encode

    /// Build a shareable universal link for the given template. The returned URL
    /// works both as an in-app universal-link target and as a regular web URL
    /// (the website falls back to a preview page when the app isn't installed).
    static func shareURL(for template: WorkoutTemplate) throws -> URL {
        let payload = SharedProgramPayload(
            v: currentVersion,
            name: template.name,
            note: template.note.isEmpty ? nil : template.note,
            exercises: template.exercises
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { exercise in
                    SharedExercisePayload(
                        name: exerciseName(for: exercise),
                        s: exercise.targetSets,
                        r: exercise.targetReps,
                        w: exercise.targetWeight,
                        rs: exercise.restSeconds,
                        n: exercise.note.isEmpty ? nil : exercise.note,
                        sup: exercise.supersetID?.uuidString
                    )
                }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let json = try encoder.encode(payload)
        let encoded = json.base64URLEncodedString()

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = pathPrefix + encoded

        guard let url = components.url else {
            throw ProgramShareError.invalidURL
        }
        return url
    }

    /// Resolves the exercise name for a template exercise. Since `WorkoutTemplateExercise`
    /// only stores `exerciseID`, the caller's modelContext must contain the matching
    /// `Exercise` row. This shared service is called from views that already have an
    /// Exercise lookup in scope, so we accept a closure-free path: callers pre-resolve
    /// and the WorkoutTemplate fetches lazily via SwiftData relationships at runtime.
    ///
    /// In practice we just need to look it up via the relationship — but the relationship
    /// isn't modeled directly, so we fall back to a sensible placeholder if missing.
    private static func exerciseName(for exercise: WorkoutTemplateExercise) -> String {
        // The Exercise row referenced by `exerciseID` may have been deleted. We use a
        // placeholder so the share at least round-trips; the recipient will see the
        // placeholder name and can re-map it.
        return ExerciseNameCache.name(for: exercise.exerciseID) ?? "Unknown Exercise"
    }

    // MARK: - Decode

    /// Returns true if the URL is in our share-link format. Cheap pre-check before
    /// attempting a full decode.
    static func isShareURL(_ url: URL) -> Bool {
        guard url.host == host else { return false }
        return url.path.hasPrefix(pathPrefix)
    }

    /// Decodes a payload from a universal-link URL. Caller is responsible for
    /// importing the payload into the current modelContext.
    static func decodePayload(from url: URL) throws -> SharedProgramPayload {
        guard isShareURL(url) else { throw ProgramShareError.invalidURL }
        let encoded = String(url.path.dropFirst(pathPrefix.count))
        guard let data = Data(base64URLEncoded: encoded) else {
            throw ProgramShareError.decodeFailed
        }
        let payload: SharedProgramPayload
        do {
            payload = try JSONDecoder().decode(SharedProgramPayload.self, from: data)
        } catch {
            throw ProgramShareError.decodeFailed
        }
        guard payload.v == currentVersion else {
            throw ProgramShareError.unsupportedVersion(payload.v)
        }
        return payload
    }

    // MARK: - Import

    /// Imports a decoded payload into the model context as a new WorkoutTemplate. Existing
    /// templates with the same name are not overwritten — the new template is inserted
    /// alongside them (caller can add a " (copy)" suffix if needed before calling).
    @discardableResult
    static func importPayload(_ payload: SharedProgramPayload, modelContext: ModelContext) throws -> WorkoutTemplate {
        // Load the recipient's exercise library so we can match by name.
        let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
        let byName = Dictionary(exercises.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })

        let template = WorkoutTemplate(
            name: payload.name,
            note: payload.note ?? "",
            isFavorite: false
        )
        modelContext.insert(template)

        // Stable supersetID mapping — the share format uses the sender's UUIDs as opaque
        // group labels, but on import we mint fresh UUIDs so future edits don't collide.
        var supersetMap: [String: UUID] = [:]

        for (index, item) in payload.exercises.enumerated() {
            let exerciseID: UUID
            if let existing = byName[item.name.lowercased()] {
                exerciseID = existing.id
            } else {
                // Recipient doesn't have this exercise — create it as a non-builtin row
                // so the program is at least functional. The user can edit it later.
                // `fullBody` is the closest match for an unknown imported exercise — the
                // user can re-categorize from the exercise detail screen.
                let placeholder = Exercise(
                    name: item.name,
                    muscleGroup: .fullBody,
                    equipmentType: "",
                    isBuiltin: false
                )
                modelContext.insert(placeholder)
                exerciseID = placeholder.id
            }

            let supersetID: UUID? = item.sup.flatMap { tag in
                if let mapped = supersetMap[tag] { return mapped }
                let new = UUID()
                supersetMap[tag] = new
                return new
            }

            let te = WorkoutTemplateExercise(
                exerciseID: exerciseID,
                sortOrder: index,
                targetSets: item.s,
                targetReps: item.r,
                targetWeight: item.w,
                restSeconds: item.rs,
                note: item.n ?? "",
                supersetID: supersetID
            )
            te.template = template
            template.exercises.append(te)
            modelContext.insert(te)
        }

        try modelContext.save()
        return template
    }
}

// MARK: - Exercise name cache

/// A tiny shared cache that lets `ProgramShareService.shareURL(for:)` resolve
/// exerciseID → name without holding a ModelContext. The cache is populated by the
/// view that triggers the share (we know it has a fetched exercise list).
enum ExerciseNameCache {
    private static var byID: [UUID: String] = [:]

    static func refresh(from exercises: [Exercise]) {
        byID = Dictionary(exercises.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    static func name(for id: UUID) -> String? {
        byID[id]
    }
}

// MARK: - Base64URL helpers

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Re-pad to multiple of 4 — base64URL strips trailing `=`.
        let pad = (4 - s.count % 4) % 4
        s += String(repeating: "=", count: pad)
        guard let data = Data(base64Encoded: s) else { return nil }
        self = data
    }
}
