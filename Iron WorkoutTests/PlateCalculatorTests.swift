//
//  PlateCalculatorTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
@testable import Iron_Workout

@Suite("PlateCalculator")
struct PlateCalculatorTests {

    private func plate(_ loading: PlateCalculator.Loading, _ weight: Double) -> Int {
        loading.perSide.first(where: { $0.weight == weight })?.count ?? 0
    }

    // MARK: - kg

    @Test("100 kg on a 20 kg bar loads two 20s and one 5 per side")
    func standardKgLoad() {
        // (100 - 20) / 2 = 40 per side -> 20 + 20
        let loading = PlateCalculator.load(target: 100, barWeight: 20, unit: .kg)
        #expect(loading.isExact)
        #expect(plate(loading, 20) == 2)
        #expect(loading.unmatchedPerSide == 0)
    }

    @Test("102.5 kg resolves to plates with no remainder")
    func fractionalKgLoad() {
        // (102.5 - 20) / 2 = 41.25 -> 25 + 15 + 1.25
        let loading = PlateCalculator.load(target: 102.5, barWeight: 20, unit: .kg)
        #expect(loading.isExact)
        #expect(plate(loading, 25) == 1)
        #expect(plate(loading, 15) == 1)
        #expect(plate(loading, 1.25) == 1)
    }

    @Test("Empty bar yields no plates")
    func barOnly() {
        let loading = PlateCalculator.load(target: 20, barWeight: 20, unit: .kg)
        #expect(loading.perSide.isEmpty)
        #expect(!loading.belowBar)
        #expect(loading.isExact)
    }

    @Test("Target below bar weight is flagged")
    func belowBar() {
        let loading = PlateCalculator.load(target: 15, barWeight: 20, unit: .kg)
        #expect(loading.belowBar)
        #expect(loading.perSide.isEmpty)
        #expect(!loading.isExact)
    }

    @Test("Unmatchable weight reports a remainder")
    func unmatchable() {
        // (21 - 20) / 2 = 0.5 per side, smaller than the smallest plate (1.25)
        let loading = PlateCalculator.load(target: 21, barWeight: 20, unit: .kg)
        #expect(loading.perSide.isEmpty)
        #expect(loading.unmatchedPerSide == 0.5)
        #expect(!loading.isExact)
    }

    // MARK: - lbs

    @Test("225 lb on a 45 lb bar loads two 45s per side")
    func standardLbLoad() {
        // (225 - 45) / 2 = 90 per side -> 45 + 45
        let loading = PlateCalculator.load(target: 225, barWeight: 45, unit: .lbs)
        #expect(loading.isExact)
        #expect(plate(loading, 45) == 2)
    }

    @Test("Inventories and bar defaults differ by unit")
    func unitDefaults() {
        #expect(PlateCalculator.defaultBarWeight(for: .kg) == 20)
        #expect(PlateCalculator.defaultBarWeight(for: .lbs) == 45)
        #expect(PlateCalculator.availablePlates(for: .kg).contains(1.25))
        #expect(PlateCalculator.availablePlates(for: .lbs).contains(45))
    }
}
