//
//  WorkoutCSVImporter.swift
//  Anvil Workout
//
//  Pure CSV parsing for importing workout history from the two largest
//  subscription competitors, Strong and Hevy. No SwiftData here — this turns
//  raw CSV text into validated value types; WorkoutCSVImportService persists them.
//
//  Parsing is header-driven (columns are matched by name, not position) so it
//  tolerates the column-order and added-column variations both apps have shipped
//  across versions. Weight is normalised to kg, the app's storage unit.
//

import Foundation

// MARK: - Parsed value types

enum WorkoutCSVFormat: String, Equatable {
    case strong = "Strong"
    case hevy = "Hevy"
}

struct ParsedImportSet: Equatable {
    let setIndex: Int
    let reps: Int
    let weightKg: Double?
    let type: SetType
    let rpe: Double?
}

struct ParsedImportExercise: Equatable {
    let name: String
    /// Raw superset grouping key from the source file (nil when not part of a superset).
    let supersetKey: String?
    /// Per-exercise note from the source file, shown in session detail. Empty when absent.
    var note: String
    var sets: [ParsedImportSet]
}

/// What the parser could not bring across. Surfaced in the import preview so a partial
/// import is a visible choice rather than a silent one (#75).
struct ParsedImportSkips: Equatable {
    /// Rows carrying only a duration or a distance: planks, timed holds, carries, cardio.
    /// `PerformedSet` stores reps and weight, so there is nowhere to put these yet.
    var timedOrDistanceSets = 0
    /// Rows whose date could not be read, so they cannot be placed in history.
    var unreadableDates = 0
    /// Rows with no exercise name.
    var namelessRows = 0
    /// Workouts whose workout-level note was dropped. `WorkoutSession` has no note field;
    /// per-exercise notes are preserved.
    var droppedWorkoutNotes = 0

    /// Rows that did not make it into the import at all.
    var droppedRows: Int { timedOrDistanceSets + unreadableDates + namelessRows }
    var isEmpty: Bool { droppedRows == 0 && droppedWorkoutNotes == 0 }
}

struct ParsedImportSession: Equatable {
    let name: String
    let startedAt: Date
    let endedAt: Date?
    var exercises: [ParsedImportExercise]
}

struct ParsedImport: Equatable {
    let format: WorkoutCSVFormat
    let sessions: [ParsedImportSession]
    /// Empty when everything in the file was imported.
    var skipped = ParsedImportSkips()

    var sessionCount: Int { sessions.count }
    var exerciseCount: Int { sessions.reduce(0) { $0 + $1.exercises.count } }
    var setCount: Int { sessions.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.sets.count } } }
}

enum WorkoutCSVImportError: LocalizedError, Equatable {
    case empty
    case unrecognizedFormat
    case noValidRows

    var errorDescription: String? {
        switch self {
        case .empty:
            return "The file is empty."
        case .unrecognizedFormat:
            return "Unrecognized CSV format. Export from Strong or Hevy and try again."
        case .noValidRows:
            return "No workouts could be read from the file."
        }
    }
}

// MARK: - Importer

enum WorkoutCSVImporter {

    private static let lbPerKg = 0.45359237

    /// Parses raw CSV text into sessions. `strongFallbackUnit` is used only for Strong
    /// exports that omit a weight-unit column; Hevy weights are always kg.
    static func parse(_ raw: String, strongFallbackUnit: WeightUnit = .kg) throws -> ParsedImport {
        let text = normalize(raw)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WorkoutCSVImportError.empty
        }

        let delimiter = detectDelimiter(firstLine: text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? "")
        let rows = tokenize(text, delimiter: delimiter).filter { !($0.count == 1 && $0[0].isEmpty) }
        guard let header = rows.first, rows.count > 1 else { throw WorkoutCSVImportError.empty }

        let columns = columnIndex(header)
        let format = try detectFormat(columns)
        let dataRows = Array(rows.dropFirst())

        let parsed: (sessions: [ParsedImportSession], skips: ParsedImportSkips)
        switch format {
        case .strong:
            parsed = parseStrong(dataRows, columns: columns, fallbackUnit: strongFallbackUnit)
        case .hevy:
            parsed = parseHevy(dataRows, columns: columns)
        }

        guard !parsed.sessions.isEmpty else { throw WorkoutCSVImportError.noValidRows }
        return ParsedImport(format: format, sessions: parsed.sessions, skipped: parsed.skips)
    }

    // MARK: - Format detection

    private static func detectFormat(_ columns: [String: Int]) throws -> WorkoutCSVFormat {
        if columns["exercise_title"] != nil || columns["weight_kg"] != nil || columns["weight_lbs"] != nil {
            return .hevy
        }
        if columns["exercise name"] != nil && columns["workout name"] != nil {
            return .strong
        }
        throw WorkoutCSVImportError.unrecognizedFormat
    }

    // MARK: - Strong

    private static func parseStrong(
        _ rows: [[String]], columns: [String: Int], fallbackUnit: WeightUnit
    ) -> (sessions: [ParsedImportSession], skips: ParsedImportSkips) {
        var builder = SessionBuilder()
        var skips = ParsedImportSkips()
        var workoutsWithNotes: Set<String> = []
        let hasUnitColumn = columns["weight unit"] != nil

        for row in rows {
            guard let date = field(row, columns, "date"), let dateValue = parseDate(date) else {
                // Ignore structurally blank rows; only count rows that carried something.
                if rowHasContent(row) { skips.unreadableDates += 1 }
                continue
            }
            let workout = field(row, columns, "workout name") ?? "Workout"
            let exerciseName = field(row, columns, "exercise name")?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !exerciseName.isEmpty else {
                skips.namelessRows += 1
                continue
            }

            let reps = Int(rounding: field(row, columns, "reps")) ?? 0
            let rawWeight = Double(localized: field(row, columns, "weight"))
            let unit = hasUnitColumn ? unitFromString(field(row, columns, "weight unit")) ?? fallbackUnit : fallbackUnit
            let weightKg = rawWeight.map { toKg($0, unit: unit) }

            let sessionKeyForNotes = date + "|" + workout
            if field(row, columns, "workout notes") != nil, workoutsWithNotes.insert(sessionKeyForNotes).inserted {
                skips.droppedWorkoutNotes += 1
            }

            // Strong exports placeholder rows with no reps and no weight. A row that instead
            // holds Seconds or Distance is real training we cannot represent yet, so it is
            // counted as a loss rather than discarded quietly.
            if reps == 0 && (weightKg ?? 0) == 0 {
                if hasPositiveValue(row, columns, in: ["seconds", "distance"]) {
                    skips.timedOrDistanceSets += 1
                }
                continue
            }

            let setOrder = Int(rounding: field(row, columns, "set order"))
            let rpe = clampedRPE(Double(localized: field(row, columns, "rpe")))
            let sessionKey = date + "|" + workout
            // Strong has no end column; it repeats the workout Duration on every row of
            // that workout. The builder keeps the value from the row that opens the
            // session, so deriving an end from the start is enough.
            let endValue = parseDuration(field(row, columns, "duration")).map(dateValue.addingTimeInterval)
            builder.add(
                sessionKey: sessionKey, sessionName: workout, startedAt: dateValue, endedAt: endValue,
                exerciseName: exerciseName, supersetKey: nil, exerciseNote: field(row, columns, "notes"),
                explicitSetIndex: setOrder.map { max(0, $0 - 1) },
                reps: reps, weightKg: weightKg, type: .working, rpe: rpe
            )
        }
        return (builder.sessions, skips)
    }

    // MARK: - Hevy

    private static func parseHevy(
        _ rows: [[String]], columns: [String: Int]
    ) -> (sessions: [ParsedImportSession], skips: ParsedImportSkips) {
        var builder = SessionBuilder()
        var skips = ParsedImportSkips()
        var workoutsWithNotes: Set<String> = []

        for row in rows {
            guard let start = field(row, columns, "start_time"), let startValue = parseDate(start) else {
                if rowHasContent(row) { skips.unreadableDates += 1 }
                continue
            }
            let title = field(row, columns, "title") ?? "Workout"
            let exerciseName = field(row, columns, "exercise_title")?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !exerciseName.isEmpty else {
                skips.namelessRows += 1
                continue
            }

            let reps = Int(rounding: field(row, columns, "reps")) ?? 0
            // Hevy names the weight column after the user's unit: weight_kg or weight_lbs.
            let weightKg: Double?
            if let kg = Double(localized: field(row, columns, "weight_kg")) {
                weightKg = kg
            } else if let lbs = Double(localized: field(row, columns, "weight_lbs")) {
                weightKg = lbs * lbPerKg
            } else {
                weightKg = nil
            }
            let sessionKeyForNotes = title + "|" + start
            if field(row, columns, "description") != nil, workoutsWithNotes.insert(sessionKeyForNotes).inserted {
                skips.droppedWorkoutNotes += 1
            }

            // Same as Strong: a row with neither reps nor weight is either a placeholder or
            // a timed/distance set the set model cannot hold. Only the latter is a loss.
            if reps == 0 && (weightKg ?? 0) == 0 {
                if hasPositiveValue(row, columns, in: ["duration_seconds", "distance_km", "distance_miles"]) {
                    skips.timedOrDistanceSets += 1
                }
                continue
            }

            let endValue = field(row, columns, "end_time").flatMap(parseDate)
            let superset = field(row, columns, "superset_id").flatMap { $0.isEmpty ? nil : $0 }
            let setIndex = Int(rounding: field(row, columns, "set_index"))
            let type = setType(fromHevy: field(row, columns, "set_type"))
            let rpe = clampedRPE(Double(localized: field(row, columns, "rpe")))
            let sessionKey = title + "|" + start

            builder.add(
                sessionKey: sessionKey, sessionName: title, startedAt: startValue, endedAt: endValue,
                exerciseName: exerciseName, supersetKey: superset, exerciseNote: field(row, columns, "exercise_notes"),
                explicitSetIndex: setIndex,
                reps: reps, weightKg: weightKg, type: type, rpe: rpe
            )
        }
        return (builder.sessions, skips)
    }

    private static func setType(fromHevy raw: String?) -> SetType {
        switch raw?.lowercased().trimmingCharacters(in: .whitespaces) {
        case "warmup", "warm up", "warm-up": return .warmup
        case "dropset", "drop set", "drop": return .drop
        case "failure", "failed": return .failure
        default: return .working
        }
    }

    // MARK: - Helpers

    private static func toKg(_ value: Double, unit: WeightUnit) -> Double {
        unit == .lbs ? value * lbPerKg : value
    }

    /// RPE clamped to the conventional 1–10 scale; out-of-range or missing → nil.
    private static func clampedRPE(_ value: Double?) -> Double? {
        guard let value, value >= 1, value <= 10 else { return nil }
        return value
    }

    private static func unitFromString(_ raw: String?) -> WeightUnit? {
        switch raw?.lowercased().trimmingCharacters(in: .whitespaces) {
        case "kg", "kgs", "kilograms": return .kg
        case "lb", "lbs", "pounds": return .lbs
        default: return nil
        }
    }

    /// True when any of `names` holds a number above zero. Used to tell a genuine timed or
    /// distance set apart from an empty placeholder row.
    private static func hasPositiveValue(_ row: [String], _ columns: [String: Int], in names: [String]) -> Bool {
        names.contains { (Double(localized: field(row, columns, $0)) ?? 0) > 0 }
    }

    /// True when the row has any non-empty cell, so trailing or structurally blank rows are
    /// not reported to the user as lost data.
    private static func rowHasContent(_ row: [String]) -> Bool {
        row.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private static func field(_ row: [String], _ columns: [String: Int], _ name: String) -> String? {
        guard let index = columns[name], index < row.count else { return nil }
        let value = row[index].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func columnIndex(_ header: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (i, name) in header.enumerated() {
            let key = name.trimmingCharacters(in: .whitespaces).lowercased()
            if map[key] == nil { map[key] = i }
        }
        return map
    }

    // MARK: - Dates

    /// Formats tried in order. Stored as Sendable strings (not DateFormatter, which is
    /// non-Sendable) so the parser stays callable from any isolation — under the app's
    /// default-MainActor Release config a shared DateFormatter static would otherwise
    /// become main-actor-isolated and unusable from this pure code.
    nonisolated private static let dateFormats: [String] = [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd",
        "d MMM yyyy, HH:mm",       // Hevy: "20 Jan 2024, 07:21"
        "MMM d yyyy, HH:mm",
        "dd/MM/yyyy HH:mm",
        "MM/dd/yyyy HH:mm:ss",
    ]

    nonisolated private static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return ISO8601DateFormatter().date(from: trimmed)
    }

    // MARK: - Durations

    /// Parses Strong's human-readable `Duration` column, e.g. "1h 2m", "45m", "1h 2m 30s",
    /// "45 min". Older exports use a clock form instead ("1:02:30", "45:30").
    ///
    /// Returns nil for anything unrecognised or zero-length so the caller falls back to a
    /// documented default rather than inventing a workout length. A bare number is
    /// deliberately not accepted: the column gives no way to tell minutes from seconds.
    nonisolated static func parseDuration(_ raw: String?) -> TimeInterval? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":").map(String.init)
            let values = parts.compactMap { Int($0) }
            guard values.count == parts.count else { return nil }
            let seconds: Int
            switch values.count {
            case 3: seconds = values[0] * 3600 + values[1] * 60 + values[2]
            case 2: seconds = values[0] * 60 + values[1]
            default: return nil
            }
            return seconds > 0 ? TimeInterval(seconds) : nil
        }

        // Unit form: scan number/unit pairs, tolerating spaces and longer unit spellings
        // ("1 h", "45 min"). Characters that are neither digits nor a unit reset the
        // pending number so "1hr 2min" reads as 1 hour and 2 minutes, not 1-2-2.
        var total: TimeInterval = 0
        var pending = ""
        for character in trimmed {
            if character.isNumber || character == "." || character == "," {
                pending.append(character == "," ? "." : character)
            } else if character.isWhitespace {
                continue
            } else if let multiplier = unitSeconds(character), let value = Double(pending) {
                total += value * multiplier
                pending = ""
            } else {
                pending = ""
            }
        }
        return total > 0 ? total : nil
    }

    /// `nonisolated` to match `parseDuration`: Release builds default to MainActor isolation,
    /// and a nonisolated caller cannot reach an isolated helper.
    nonisolated private static func unitSeconds(_ character: Character) -> TimeInterval? {
        switch character {
        case "h": return 3600
        case "m": return 60
        case "s": return 1
        default: return nil
        }
    }

    // MARK: - Text normalization & tokenizing

    private static func normalize(_ raw: String) -> String {
        var text = raw
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        return text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    private static func detectDelimiter(firstLine: String) -> Character {
        let commas = firstLine.filter { $0 == "," }.count
        let semicolons = firstLine.filter { $0 == ";" }.count
        let tabs = firstLine.filter { $0 == "\t" }.count
        if semicolons > commas && semicolons >= tabs { return ";" }
        if tabs > commas && tabs > semicolons { return "\t" }
        return ","
    }

    /// Minimal RFC 4180 tokenizer: handles quoted fields, escaped quotes ("") and
    /// delimiters/newlines inside quotes.
    private static func tokenize(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.makeIterator()
        var pending: Character? = iterator.next()

        func advance() -> Character? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }

        var current = advance()
        while let c = current {
            if inQuotes {
                if c == "\"" {
                    let next = advance()
                    if next == "\"" { field.append("\"") } else { inQuotes = false; current = next; continue }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case delimiter: row.append(field); field = ""
                case "\n": row.append(field); rows.append(row); row = []; field = ""
                default: field.append(c)
                }
            }
            current = advance()
        }
        row.append(field)
        rows.append(row)
        return rows
    }
}

// MARK: - Lenient number parsing

private extension Int {
    /// Parses "12", "12.0", "12.7" → 12 (rounds), tolerating decimals Strong/Hevy emit for reps.
    init?(rounding string: String?) {
        guard let string, let value = Double(localized: string) else { return nil }
        self = Int(value.rounded())
    }
}

private extension Double {
    /// Parses a number tolerating a comma decimal separator and surrounding whitespace.
    init?(localized string: String?) {
        guard let string else { return nil }
        let cleaned = string.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned) else { return nil }
        self = value
    }
}

// MARK: - Session grouping

/// Accumulates flat rows into ordered sessions → exercises → sets, preserving
/// first-seen order at every level so imported history reads like the original.
private struct SessionBuilder {
    private(set) var sessions: [ParsedImportSession] = []
    private var sessionOrder: [String] = []
    private var sessionByKey: [String: Int] = [:]
    // Per session: exercise name → index, and a running set counter for implicit indices.
    private var exerciseOrderBySession: [String: [String: Int]] = [:]
    private var setCounter: [String: Int] = [:]

    mutating func add(
        sessionKey: String, sessionName: String, startedAt: Date, endedAt: Date?,
        exerciseName: String, supersetKey: String?, exerciseNote: String?,
        explicitSetIndex: Int?, reps: Int, weightKg: Double?, type: SetType, rpe: Double?
    ) {
        let sIndex: Int
        if let existing = sessionByKey[sessionKey] {
            sIndex = existing
        } else {
            sIndex = sessions.count
            sessionByKey[sessionKey] = sIndex
            sessions.append(ParsedImportSession(name: sessionName, startedAt: startedAt, endedAt: endedAt, exercises: []))
            exerciseOrderBySession[sessionKey] = [:]
        }

        let exIndex: Int
        if let existing = exerciseOrderBySession[sessionKey]?[exerciseName] {
            exIndex = existing
        } else {
            exIndex = sessions[sIndex].exercises.count
            exerciseOrderBySession[sessionKey]?[exerciseName] = exIndex
            sessions[sIndex].exercises.append(
                ParsedImportExercise(name: exerciseName, supersetKey: supersetKey, note: "", sets: [])
            )
        }

        // Both apps repeat the exercise note on every set row; keep the first non-empty one.
        if sessions[sIndex].exercises[exIndex].note.isEmpty, let exerciseNote, !exerciseNote.isEmpty {
            sessions[sIndex].exercises[exIndex].note = exerciseNote
        }

        let setKey = sessionKey + "|" + exerciseName
        let nextImplicit = setCounter[setKey] ?? 0
        setCounter[setKey] = nextImplicit + 1
        let setIndex = explicitSetIndex ?? nextImplicit

        sessions[sIndex].exercises[exIndex].sets.append(
            ParsedImportSet(setIndex: setIndex, reps: reps, weightKg: weightKg, type: type, rpe: rpe)
        )
    }
}
