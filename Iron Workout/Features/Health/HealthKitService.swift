//
//  HealthKitService.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import HealthKit

final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private var currentBuilder: HKWorkoutBuilder?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private init() {}

    /// Typer vi vil læse og skrive.
    private static var typesToShare: Set<HKSampleType> {
        [HKObjectType.workoutType()]
    }

    private static var typesToRead: Set<HKObjectType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
        ]
    }

    /// Anmod om tilladelse (kaldes før første træning eller fra Indstillinger).
    @MainActor
    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: Self.typesToShare, read: Self.typesToRead)
    }

    /// Tjekker om vi har tilladelse til at skrive workouts (groft check).
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        store.authorizationStatus(for: type)
    }

    /// Start HealthKit-workout (kaldes når brugeren starter træning).
    @MainActor
    func startWorkout(startDate: Date) async throws {
        guard isAvailable else { return }
        currentBuilder?.discardWorkout()
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: nil)
        try await builder.beginCollection(at: startDate)
        currentBuilder = builder
    }

    /// Afslut og gem workout; returnerer kcal og gns. puls for intervallet (fra Health).
    @MainActor
    func endWorkout(endDate: Date) async throws -> (calories: Double?, averageHeartRate: Double?) {
        guard let builder = currentBuilder else {
            currentBuilder = nil
            return (nil, nil)
        }
        defer { currentBuilder = nil }
        try await builder.endCollection(at: endDate)
        guard let workout = try await builder.finishWorkout() else {
            return (nil, nil)
        }
        let (cal, hr) = await queryWorkoutMetrics(from: workout.startDate, to: workout.endDate)
        return (cal, hr)
    }

    /// Kasser workout uden at gemme (fx ved annullering).
    func discardWorkout() {
        currentBuilder?.discardWorkout()
        currentBuilder = nil
    }

    /// Hent forbrugte kcal og gennemsnitlig puls for et tidsinterval fra Health.
    private func queryWorkoutMetrics(from start: Date, to end: Date) async -> (calories: Double?, averageHeartRate: Double?) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let calories: Double? = await withCheckedContinuation { cont in
            let calType = HKQuantityType(.activeEnergyBurned)
            let q = HKStatisticsQuery(
                quantityType: calType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if error != nil { cont.resume(returning: nil); return }
                let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie())
                cont.resume(returning: value)
            }
            store.execute(q)
        }

        let heartRate: Double? = await withCheckedContinuation { cont in
            let hrType = HKQuantityType(.heartRate)
            let q = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if error != nil { cont.resume(returning: nil); return }
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    cont.resume(returning: nil)
                    return
                }
                let unit = HKUnit(from: "count/min")
                let sum = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
                cont.resume(returning: sum / Double(samples.count))
            }
            store.execute(q)
        }

        return (calories, heartRate)
    }
}
