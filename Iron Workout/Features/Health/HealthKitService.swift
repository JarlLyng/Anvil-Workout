//
//  HealthKitService.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import HealthKit
import Sentry

final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private var currentBuilder: HKWorkoutBuilder?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private init() {}

    /// Types we want to read and write.
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

    /// Request authorization (called before first workout or from Settings).
    @MainActor
    func requestAuthorization() async throws {
        guard isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: Self.typesToShare, read: Self.typesToRead)
        } catch {
            SentrySDK.capture(error: error)
            throw error
        }
    }

    /// Checks if we have authorization to write workouts.
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        store.authorizationStatus(for: type)
    }

    /// True only when the user has explicitly granted write access for workouts.
    /// HealthKit reports `.sharingDenied` for both denied and not-yet-determined read access,
    /// so we gate on the write status, which is unambiguous.
    var isWorkoutWritingAuthorized: Bool {
        guard isAvailable else { return false }
        return store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    private func logAuthSkip(_ context: String) {
        let crumb = Breadcrumb(level: .info, category: "healthkit")
        crumb.message = "Skipped \(context): authorization not granted"
        SentrySDK.addBreadcrumb(crumb)
    }

    /// Start HealthKit workout (called when the user starts a workout).
    @MainActor
    func startWorkout(startDate: Date) async throws {
        guard isAvailable else { return }
        guard isWorkoutWritingAuthorized else {
            logAuthSkip("startWorkout")
            return
        }
        currentBuilder?.discardWorkout()
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: nil)
        do {
            try await builder.beginCollection(at: startDate)
            currentBuilder = builder
        } catch {
            SentrySDK.capture(error: error)
            throw error
        }
    }

    /// End and save workout; returns kcal and avg. heart rate for the interval (from Health).
    @MainActor
    func endWorkout(endDate: Date) async throws -> (calories: Double?, averageHeartRate: Double?) {
        guard let builder = currentBuilder else {
            currentBuilder = nil
            return (nil, nil)
        }
        defer { currentBuilder = nil }
        guard isWorkoutWritingAuthorized else {
            logAuthSkip("endWorkout")
            builder.discardWorkout()
            return (nil, nil)
        }
        do {
            try await builder.endCollection(at: endDate)
        } catch {
            SentrySDK.capture(error: error)
            throw error
        }
        guard let workout = try await builder.finishWorkout() else {
            return (nil, nil)
        }
        let (cal, hr) = await queryWorkoutMetrics(from: workout.startDate, to: workout.endDate)
        return (cal, hr)
    }

    /// Discard workout without saving (e.g. on cancel).
    func discardWorkout() {
        currentBuilder?.discardWorkout()
        currentBuilder = nil
    }

    /// Fetch calories burned and average heart rate for a time interval from Health.
    private func queryWorkoutMetrics(from start: Date, to end: Date) async -> (calories: Double?, averageHeartRate: Double?) {
        // HealthKit doesn't expose read-authorization status (privacy), so we use workout
        // write-auth as a proxy — a user who blocked workouts almost certainly blocked reads.
        guard isWorkoutWritingAuthorized else {
            logAuthSkip("queryWorkoutMetrics")
            return (nil, nil)
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let calories: Double? = await withCheckedContinuation { cont in
            let calType = HKQuantityType(.activeEnergyBurned)
            let q = HKStatisticsQuery(
                quantityType: calType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error { SentrySDK.capture(error: error); cont.resume(returning: nil); return }
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
                if let error { SentrySDK.capture(error: error); cont.resume(returning: nil); return }
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
