//
//  WeightFormatter.swift
//  Anvil Workout
//

import Foundation
import SwiftUI

/// User-facing weight unit. Storage is always kg; this only affects display and input.
enum WeightUnit: String, CaseIterable, Identifiable {
    case kg
    case lbs

    var id: String { rawValue }
    var label: String { self == .lbs ? "lb" : "kg" }

    /// Stepper increment that feels natural in each unit (2.5 kg ≈ 5.5 lb, rounded to 5).
    var stepperIncrement: Double { self == .lbs ? 5 : 2.5 }
}

enum WeightFormatter {
    static let appStorageKey = "weightUnit"
    private static let kgPerLb = 0.45359237

    static var current: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: appStorageKey) ?? WeightUnit.kg.rawValue) ?? .kg
    }

    /// kg → user-unit value (kg or lbs).
    static func display(_ kg: Double, in unit: WeightUnit = current) -> Double {
        unit == .lbs ? kg / kgPerLb : kg
    }

    /// User-unit value → kg for storage.
    static func toKg(_ value: Double, from unit: WeightUnit = current) -> Double {
        unit == .lbs ? value * kgPerLb : value
    }

    /// "100.0 kg" / "220.5 lb" — pass the kg value, get the formatted string in the active unit.
    static func format(kg: Double, fractionDigits: Int = 1, in unit: WeightUnit = current) -> String {
        let value = display(kg, in: unit)
        return "\(value.formatted(.number.precision(.fractionLength(fractionDigits)))) \(unit.label)"
    }

    /// "100 kg", "102.5 kg", "225 lb": a decimal only where the weight has one, so a
    /// half-kilo target does not round away and a whole one does not read "100.0".
    static func compact(kg: Double, in unit: WeightUnit = current) -> String {
        format(kg: kg, fractionDigits: fractionDigits(for: display(kg, in: unit)), in: unit)
    }

    /// Volume, "11,899 kg": whole units, since a decimal on a total of thousands is noise.
    static func volume(kg: Double, in unit: WeightUnit = current) -> String {
        format(kg: kg, fractionDigits: 0, in: unit)
    }

    /// 0 when the value would show as "x.0" at one decimal, 1 otherwise. That also absorbs
    /// the float error in a pound value that went through kilograms for storage.
    static func fractionDigits(for value: Double) -> Int {
        abs(value - value.rounded()) < 0.05 ? 0 : 1
    }

    /// Two-way Binding for an optional kg-stored Double exposed in the active unit.
    static func displayBinding(kg: Binding<Double?>, unit: WeightUnit = current) -> Binding<Double?> {
        Binding(
            get: { kg.wrappedValue.map { display($0, in: unit) } },
            set: { kg.wrappedValue = $0.map { toKg($0, from: unit) } }
        )
    }
}
