//
//  HealthService.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import HealthKit
import CoreLocation

/// Production implementation of HealthServiceProtocol using HKHealthStore
final class HealthService: HealthServiceProtocol, @unchecked Sendable {
    private let healthStore: HKHealthStore

    /// Types of data we need to read from HealthKit
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        // Workout type
        if let workoutType = HKObjectType.workoutType() as HKObjectType? {
            types.insert(workoutType)
        }

        // Heart rate
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRateType)
        }

        // Route
        if let routeType = HKSeriesType.workoutRoute() as HKObjectType? {
            types.insert(routeType)
        }

        return types
    }

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws -> HealthKitAuthorizationStatus {
        guard isHealthDataAvailable else {
            throw HealthServiceError.healthKitNotAvailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        // HealthKit does not provide reliable per-type read authorization status via
        // `authorizationStatus(for:)`; that API is for sharing (write) status.
        // If authorization request succeeds, proceed and validate access via reads.
        return .authorized
    }

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        guard isHealthDataAvailable else {
            throw HealthServiceError.healthKitNotAvailable
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        // Filter to GPS-based cardio workouts
        let workoutTypes: [HKWorkoutActivityType] = [
            .running,
            .cycling,
            .swimming,
            .hiking,
            .walking
        ]

        let typePredicate = NSCompoundPredicate(orPredicateWithSubpredicates:
            workoutTypes.map { HKQuery.predicateForWorkouts(with: $0) }
        )

        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, typePredicate])

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: combinedPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: self.mapHealthKitError(error))
                    return
                }

                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }

    func fetchRoute(for workout: HKWorkout) async throws -> [CLLocation]? {
        guard isHealthDataAvailable else {
            throw HealthServiceError.healthKitNotAvailable
        }

        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        // First, get the route object
        let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: self.mapHealthKitError(error))
                    return
                }

                let routes = (samples as? [HKWorkoutRoute]) ?? []
                continuation.resume(returning: routes)
            }

            healthStore.execute(query)
        }

        guard let route = routes.first else {
            return nil
        }

        // Now get the location data from the route
        return try await withCheckedThrowingContinuation { continuation in
            var allLocations: [CLLocation] = []

            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error = error {
                    continuation.resume(throwing: self.mapHealthKitError(error))
                    return
                }

                if let locations = locations {
                    allLocations.append(contentsOf: locations)
                }

                if done {
                    continuation.resume(returning: allLocations)
                }
            }

            healthStore.execute(query)
        }
    }

    func fetchHeartRateData(for workout: HKWorkout) async throws -> (average: Double, max: Double)? {
        guard isHealthDataAvailable else {
            throw HealthServiceError.healthKitNotAvailable
        }

        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: self.mapHealthKitError(error))
                    return
                }

                guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                let heartRates = quantitySamples.map { $0.quantity.doubleValue(for: unit) }

                let average = heartRates.reduce(0, +) / Double(heartRates.count)
                let max = heartRates.max() ?? 0

                continuation.resume(returning: (average: average, max: max))
            }

            healthStore.execute(query)
        }
    }

    private func mapHealthKitError(_ error: Error) -> HealthServiceError {
        if let hkError = error as? HKError {
            switch hkError.code {
            case .errorAuthorizationDenied, .errorHealthDataRestricted:
                return .authorizationDenied
            default:
                break
            }
        }

        return .fetchFailed(underlying: error)
    }
}
