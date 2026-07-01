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
    var sets: [ParsedImportSet]
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

        let sessions: [ParsedImportSession]
        switch format {
        case .strong:
            sessions = parseStrong(dataRows, columns: columns, fallbackUnit: strongFallbackUnit)
        case .hevy:
            sessions = parseHevy(dataRows, columns: columns)
        }

        guard !sessions.isEmpty else { throw WorkoutCSVImportError.noValidRows }
        return ParsedImport(format: format, sessions: sessions)
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

    private static func parseStrong(_ rows: [[String]], columns: [String: Int], fallbackUnit: WeightUnit) -> [ParsedImportSession] {
        var builder = SessionBuilder()
        let hasUnitColumn = columns["weight unit"] != nil

        for row in rows {
            guard let date = field(row, columns, "date"), let dateValue = parseDate(date) else { continue }
            let workout = field(row, columns, "workout name") ?? "Workout"
            let exerciseName = field(row, columns, "exercise name")?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !exerciseName.isEmpty else { continue }

            let reps = Int(rounding: field(row, columns, "reps")) ?? 0
            let rawWeight = Double(localized: field(row, columns, "weight"))
            let unit = hasUnitColumn ? unitFromString(field(row, columns, "weight unit")) ?? fallbackUnit : fallbackUnit
            let weightKg = rawWeight.map { toKg($0, unit: unit) }

            // Skip rows with no data at all (Strong sometimes exports placeholder rows).
            if reps == 0 && (weightKg ?? 0) == 0 { continue }

            let setOrder = Int(rounding: field(row, columns, "set order"))
            let rpe = clampedRPE(Double(localized: field(row, columns, "rpe")))
            let sessionKey = date + "|" + workout
            builder.add(
                sessionKey: sessionKey, sessionName: workout, startedAt: dateValue, endedAt: nil,
                exerciseName: exerciseName, supersetKey: nil,
                explicitSetIndex: setOrder.map { max(0, $0 - 1) },
                reps: reps, weightKg: weightKg, type: .working, rpe: rpe
            )
        }
        return builder.sessions
    }

    // MARK: - Hevy

    private static func parseHevy(_ rows: [[String]], columns: [String: Int]) -> [ParsedImportSession] {
        var builder = SessionBuilder()

        for row in rows {
            guard let start = field(row, columns, "start_time"), let startValue = parseDate(start) else { continue }
            let title = field(row, columns, "title") ?? "Workout"
            let exerciseName = field(row, columns, "exercise_title")?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !exerciseName.isEmpty else { continue }

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
            if reps == 0 && (weightKg ?? 0) == 0 { continue }

            let endValue = field(row, columns, "end_time").flatMap(parseDate)
            let superset = field(row, columns, "superset_id").flatMap { $0.isEmpty ? nil : $0 }
            let setIndex = Int(rounding: field(row, columns, "set_index"))
            let type = setType(fromHevy: field(row, columns, "set_type"))
            let rpe = clampedRPE(Double(localized: field(row, columns, "rpe")))
            let sessionKey = title + "|" + start

            builder.add(
                sessionKey: sessionKey, sessionName: title, startedAt: startValue, endedAt: endValue,
                exerciseName: exerciseName, supersetKey: superset,
                explicitSetIndex: setIndex,
                reps: reps, weightKg: weightKg, type: type, rpe: rpe
            )
        }
        return builder.sessions
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
        exerciseName: String, supersetKey: String?,
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
            sessions[sIndex].exercises.append(ParsedImportExercise(name: exerciseName, supersetKey: supersetKey, sets: []))
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
