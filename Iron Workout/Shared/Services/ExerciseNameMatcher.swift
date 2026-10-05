//
//  ExerciseNameMatcher.swift
//  Anvil Workout
//
//  Maps exercise names from Strong and Hevy onto the built-in library. Both apps put the
//  equipment in brackets, "Bench Press (Barbell)", and use a few names of their own, so an
//  exact match missed nearly every lift: history came in as custom exercises filed under
//  Full Body, split from the library exercises the lifter's programs use. Pure, so the
//  rules can be tested without a store.
//

import Foundation

enum ExerciseNameMatcher {

    /// What the matcher needs to know about a library exercise.
    struct Entry: Equatable {
        let name: String
        let equipment: String
        let muscleGroup: MuscleGroup
    }

    enum Resolution: Equatable {
        /// The library exercise, by name, that the imported name means.
        case library(String)
        /// No library exercise is the same lift: a custom one, in this muscle group.
        case custom(MuscleGroup)
    }

    /// Resolves an imported name against the library, in order:
    /// 1. An exercise the library names after its equipment: "Bench Press (Dumbbell)" is
    ///    "Dumbbell Bench Press".
    /// 2. A name the other apps use for one kind of equipment: "Overhead Press (Dumbbell)"
    ///    is "Dumbbell Shoulder Press".
    /// 3. The same movement, under its name or a known alias ("Squat" is "Back Squat"), when
    ///    the equipment fits. "Bench Press (Dumbbell)" never becomes the barbell bench press.
    /// Anything else is a custom exercise, in the muscle group its movement belongs to.
    static func resolve(_ importedName: String, library: [Entry]) -> Resolution {
        let (base, equipment) = parts(of: importedName)
        let movement = baseAliases[base] ?? base
        var byName: [String: Entry] = [:]
        for entry in library where byName[normalize(entry.name)] == nil {
            byName[normalize(entry.name)] = entry
        }

        if let equipment {
            for candidate in ["\(equipment) \(movement)", "\(equipment) \(base)"] {
                if let entry = byName[candidate] { return .library(entry.name) }
            }
            if let name = equipmentAliases["\(base)|\(equipment)"], let entry = byName[normalize(name)] {
                return .library(entry.name)
            }
        }
        if let entry = byName[movement] {
            return compatible(equipment, entry.equipment) ? .library(entry.name) : .custom(entry.muscleGroup)
        }
        return .custom(muscleGroup(of: movement) ?? .fullBody)
    }

    // MARK: - Names

    /// "Seated Cable Row - V Grip (Cable)" → ("seated cable row", "cable"). The bracket is
    /// the equipment, a dash adds a grip or variant, which is left out.
    static func parts(of name: String) -> (base: String, equipment: String?) {
        var base = name.trimmingCharacters(in: .whitespaces)
        var equipment: String?
        if base.hasSuffix(")"), let open = base.lastIndex(of: "(") {
            let inner = base[base.index(after: open)..<base.index(before: base.endIndex)]
            equipment = normalizeEquipment(String(inner))
            base = String(base[..<open])
        }
        if let dash = base.range(of: " - ") {
            base = String(base[..<dash.lowerBound])
        }
        return (normalize(base), equipment)
    }

    /// Lowercased, hyphens as spaces, single spaces: "Pull-Up" and "Pull Up" are one name.
    static func normalize(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// "Cable - Straight Bar" → "cable"; an EZ bar is a barbell for matching.
    private static func normalizeEquipment(_ raw: String) -> String? {
        let first = raw.components(separatedBy: " - ").first ?? raw
        let equipment = normalize(first)
        if equipment.isEmpty { return nil }
        return equipment == "ez bar" ? "barbell" : equipment
    }

    /// Movements Strong and Hevy name differently from the library, whatever the equipment.
    /// The equipment is still checked against the library exercise.
    private static let baseAliases: [String: String] = [
        "squat": "back squat",
        "barbell squat": "back squat",
        "bent over row": "barbell row",
        "bent over barbell row": "barbell row",
        "bicep curl": "curl",
        "biceps curl": "curl",
        "triceps pushdown": "tricep pushdown",
        "triceps rope pushdown": "rope pushdown",
        "overhead triceps extension": "overhead tricep extension",
        "triceps dip": "tricep dip",
        "chest dip": "dip",
        "lying leg curl": "leg curl",
        "seated leg curl": "leg curl",
        "seated cable row": "cable row",
        "cable crossover": "cable fly",
        "skull crusher": "skullcrusher",
        "lying triceps extension": "skullcrusher",
        "military press": "overhead press",
        "strict military press": "overhead press",
        "standing overhead press": "overhead press",
        "conventional deadlift": "deadlift",
        "rdl": "romanian deadlift",
        "ab wheel": "ab wheel rollout",
    ]

    /// Names that mean a different library exercise with one kind of equipment only.
    private static let equipmentAliases: [String: String] = [
        "overhead press|dumbbell": "Dumbbell Shoulder Press",
        "shoulder press|barbell": "Overhead Press",
        "chest fly|dumbbell": "Dumbbell Fly",
        "chest fly|cable": "Cable Fly",
        "incline curl|dumbbell": "Incline Dumbbell Curl",
        "triceps extension|dumbbell": "Overhead Tricep Extension",
    ]

    // MARK: - Equipment

    /// Whether imported equipment fits a library exercise's. No equipment in the name fits
    /// anything; free weights must be the same kind; machines and cables stand in for each
    /// other; a weighted bodyweight exercise is still that exercise, an assisted one is not.
    static func compatible(_ imported: String?, _ library: String) -> Bool {
        guard let imported else { return true }
        let library = library.lowercased()
        if imported == library { return true }
        let machines: Set<String> = ["machine", "cable", "smith machine", "plate loaded"]
        if machines.contains(imported) && machines.contains(library) { return true }
        return imported == "weighted" && library == "bodyweight"
    }

    // MARK: - Muscle group

    /// The muscle group a movement's name points to, for a custom exercise. Checked in
    /// order, at the start of a word, so "leg raise" is core before "raise" is shoulders and
    /// "narrow" is never a row.
    static func muscleGroup(of movement: String) -> MuscleGroup? {
        let padded = " \(movement) "
        return keywordGroups.first { padded.contains(" \($0.keyword)") }?.group
    }

    private static let keywordGroups: [(keyword: String, group: MuscleGroup)] = [
        ("leg raise", .core), ("knee raise", .core), ("crunch", .core), ("plank", .core),
        ("sit up", .core), ("twist", .core), ("ab wheel", .core), ("woodchop", .core),
        ("calf", .legs), ("calv", .legs), ("leg curl", .legs), ("leg press", .legs),
        ("leg extension", .legs), ("squat", .legs), ("lunge", .legs), ("step up", .legs),
        ("glute", .legs), ("hip", .legs), ("romanian", .legs),
        ("face pull", .shoulders), ("rear delt", .shoulders), ("reverse fly", .back),
        ("curl", .arms), ("tricep", .arms), ("bicep", .arms), ("skull", .arms),
        ("pushdown", .arms), ("kickback", .arms),
        ("bench", .chest), ("chest", .chest), ("fly", .chest), ("push up", .chest), ("dip", .chest),
        ("deadlift", .back), ("row", .back), ("pull", .back), ("lat", .back), ("chin", .back),
        ("shrug", .back),
        ("raise", .shoulders), ("shoulder", .shoulders), ("overhead press", .shoulders),
        ("military", .shoulders), ("delt", .shoulders),
    ]
}
