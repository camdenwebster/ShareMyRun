//
//  WorkoutRepository.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import HealthKit
import SwiftData
import CoreLocation

/// Protocol defining the interface for workout data operations
/// Coordinates between HealthKit and local SwiftData storage
protocol WorkoutRepositoryProtocol: Sendable {
    /// Fetches workouts from HealthKit for the last 30 days and saves to local storage
    /// - Parameter modelContext: The SwiftData model context to save to
    /// - Returns: Array of imported Workout objects
    func syncWorkouts(modelContext: ModelContext) async throws -> [Workout]

    /// Fetches all locally stored workouts
    /// - Parameter modelContext: The SwiftData model context to query
    /// - Returns: Array of stored Workout objects
    func fetchStoredWorkouts(modelContext: ModelContext) throws -> [Workout]

    /// Fetches a single workout by its HealthKit ID
    /// - Parameters:
    ///   - healthKitID: The HealthKit UUID string
    ///   - modelContext: The SwiftData model context to query
    /// - Returns: The workout if found, nil otherwise
    func fetchWorkout(healthKitID: String, modelContext: ModelContext) throws -> Workout?
}

/// Production implementation of WorkoutRepositoryProtocol
final class WorkoutRepository: WorkoutRepositoryProtocol, @unchecked Sendable {
    private let healthService: HealthServiceProtocol

    init(healthService: HealthServiceProtocol = HealthService()) {
        self.healthService = healthService
    }

    func syncWorkouts(modelContext: ModelContext) async throws -> [Workout] {
        // Request authorization first. Read access is validated by the read queries.
        _ = try await healthService.requestAuthorization()

        // Fetch workouts from the last 30 days
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate

        let hkWorkouts = try await healthService.fetchWorkouts(from: startDate, to: endDate)

        var importedWorkouts: [Workout] = []

        for hkWorkout in hkWorkouts {
            // Check if we already have this workout
            let healthKitID = hkWorkout.uuid.uuidString
            if let existing = try fetchWorkout(healthKitID: healthKitID, modelContext: modelContext) {
                importedWorkouts.append(existing)
                continue
            }

            // Convert and save new workout
            let workout = try await convertHKWorkout(hkWorkout)
            modelContext.insert(workout)
            importedWorkouts.append(workout)
        }

        // Save changes
        try modelContext.save()

        return importedWorkouts
    }

    func fetchStoredWorkouts(modelContext: ModelContext) throws -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchWorkout(healthKitID: String, modelContext: ModelContext) throws -> Workout? {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.healthKitID == healthKitID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Private Helpers

    /// Converts an HKWorkout to our Workout model
    private func convertHKWorkout(_ hkWorkout: HKWorkout) async throws -> Workout {
        let workoutType = mapWorkoutType(hkWorkout.workoutActivityType)

        // Get distance
        let distance = hkWorkout.totalDistance?.doubleValue(for: .meter())

        // Get calories
        let calories = hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie())

        // Calculate average pace (seconds per meter)
        var averagePace: Double? = nil
        if let distance = distance, distance > 0 {
            averagePace = hkWorkout.duration / distance
        }

        // Fetch route data
        var routeCoordinates: [RouteCoordinate]? = nil
        if let locations = try await healthService.fetchRoute(for: hkWorkout) {
            routeCoordinates = locations.map { RouteCoordinate(location: $0) }
        }

        // Fetch heart rate data
        var avgHeartRate: Double? = nil
        var maxHeartRate: Double? = nil
        if let heartRateData = try await healthService.fetchHeartRateData(for: hkWorkout) {
            avgHeartRate = heartRateData.average
            maxHeartRate = heartRateData.max
        }

        // Get elevation gain from workout metadata
        var elevationGain: Double? = nil
        if let elevation = hkWorkout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
            elevationGain = elevation.doubleValue(for: .meter())
        }

        return Workout(
            healthKitID: hkWorkout.uuid.uuidString,
            type: workoutType,
            startDate: hkWorkout.startDate,
            endDate: hkWorkout.endDate,
            distance: distance,
            duration: hkWorkout.duration,
            routeCoordinates: routeCoordinates,
            calories: calories,
            averageHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            averagePace: averagePace,
            elevationGain: elevationGain
        )
    }

    /// Maps HKWorkoutActivityType to our WorkoutType enum
    private func mapWorkoutType(_ hkType: HKWorkoutActivityType) -> WorkoutType {
        switch hkType {
        case .running:
            return .running
        case .cycling:
            return .cycling
        case .swimming:
            return .swimming
        case .hiking:
            return .hiking
        case .walking:
            return .walking
        default:
            return .other
        }
    }
}

// MARK: - Mock Repository for Testing

final class MockWorkoutRepository: WorkoutRepositoryProtocol, @unchecked Sendable {
    nonisolated(unsafe) var mockWorkouts: [Workout] = []
    nonisolated(unsafe) var shouldThrowOnSync: Bool = false
    nonisolated(unsafe) var syncError: Error = HealthServiceError.authorizationDenied

    nonisolated(unsafe) private(set) var syncWorkoutsCallCount = 0
    nonisolated(unsafe) private(set) var fetchStoredWorkoutsCallCount = 0

    func syncWorkouts(modelContext: ModelContext) async throws -> [Workout] {
        syncWorkoutsCallCount += 1

        if shouldThrowOnSync {
            throw syncError
        }

        // Insert mock workouts into context
        for workout in mockWorkouts {
            modelContext.insert(workout)
        }

        return mockWorkouts
    }

    func fetchStoredWorkouts(modelContext: ModelContext) throws -> [Workout] {
        fetchStoredWorkoutsCallCount += 1
        return mockWorkouts
    }

    func fetchWorkout(healthKitID: String, modelContext: ModelContext) throws -> Workout? {
        return mockWorkouts.first { $0.healthKitID == healthKitID }
    }

    func reset() {
        syncWorkoutsCallCount = 0
        fetchStoredWorkoutsCallCount = 0
        mockWorkouts = []
    }
}
