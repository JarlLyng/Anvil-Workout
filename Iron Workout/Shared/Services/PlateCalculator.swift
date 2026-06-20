//
//  PlateCalculator.swift
//  Anvil Workout
//

import Foundation

/// Pure, unit-aware barbell loading math. All values are expressed in the user's
/// active weight unit (plates are physical objects, so kg and lb inventories differ).
/// Storage elsewhere is always kg; convert before/after if needed.
enum PlateCalculator {

    /// One plate denomination loaded a number of times on each side of the bar.
    struct LoadedPlate: Equatable, Identifiable {
        let weight: Double
        let count: Int
        var id: Double { weight }
    }

    /// Result of loading a target weight onto a bar.
    struct Loading: Equatable {
        /// Plates per side, heaviest first.
        let perSide: [LoadedPlate]
        /// Weight per side that could not be matched with the available plates
        /// (0 when the target is achievable exactly). Always in the active unit.
        let unmatchedPerSide: Double
        /// True when the target is lighter than the empty bar.
        let belowBar: Bool

        var isExact: Bool { unmatchedPerSide == 0 && !belowBar }
    }

    /// Standard plate denominations available per side, heaviest first.
    static func availablePlates(for unit: WeightUnit) -> [Double] {
        unit == .lbs ? [45, 35, 25, 10, 5, 2.5] : [25, 20, 15, 10, 5, 2.5, 1.25]
    }

    /// Sensible default empty-bar weight in the given unit (Olympic bar).
    static func defaultBarWeight(for unit: WeightUnit) -> Double {
        unit == .lbs ? 45 : 20
    }

    /// Greedily load `target` onto a bar of `barWeight` using `plates` (unlimited count
    /// per denomination, which matches how a plate calculator is used in practice).
    /// All arguments and results are in the same unit.
    static func load(target: Double, barWeight: Double, plates: [Double]? = nil, unit: WeightUnit = WeightFormatter.current) -> Loading {
        let inventory = (plates ?? availablePlates(for: unit)).sorted(by: >)

        guard target >= barWeight else {
            return Loading(perSide: [], unmatchedPerSide: 0, belowBar: true)
        }

        // Tiny epsilon guards against floating-point drift (e.g. 2.5 + 2.5 + ... ≠ exact).
        var remaining = (target - barWeight) / 2
        let epsilon = 0.0001
        var loaded: [LoadedPlate] = []

        for plate in inventory {
            guard plate > 0 else { continue }
            let count = Int((remaining + epsilon) / plate)
            if count > 0 {
                loaded.append(LoadedPlate(weight: plate, count: count))
                remaining -= Double(count) * plate
            }
        }

        let unmatched = remaining < epsilon ? 0 : remaining
        return Loading(perSide: loaded, unmatchedPerSide: unmatched, belowBar: false)
    }
}
