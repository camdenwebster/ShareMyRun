//
//  HealthServiceProtocol.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import HealthKit

/// Represents the authorization status for HealthKit access
enum HealthKitAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
}

/// Protocol defining the interface for HealthKit operations
/// Enables dependency injection and testability
protocol HealthServiceProtocol: Sendable {
    /// Checks if HealthKit is available on this device
    var isHealthDataAvailable: Bool { get }

    /// Requests authorization to read workout data from HealthKit
    /// - Returns: The resulting authorization status
    func requestAuthorization() async throws -> HealthKitAuthorizationStatus

    /// Fetches workouts from HealthKit within the specified date range
    /// - Parameters:
    ///   - startDate: The start of the date range
    ///   - endDate: The end of the date range
    /// - Returns: Array of HKWorkout objects
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout]

    /// Fetches the route data for a specific workout
    /// - Parameter workout: The workout to fetch route data for
    /// - Returns: Array of CLLocation objects representing the route, or nil if no route exists
    func fetchRoute(for workout: HKWorkout) async throws -> [CLLocation]?

    /// Fetches heart rate samples for a specific workout
    /// - Parameter workout: The workout to fetch heart rate data for
    /// - Returns: Tuple containing average and max heart rate, or nil if unavailable
    func fetchHeartRateData(for workout: HKWorkout) async throws -> (average: Double, max: Double)?
}

import CoreLocation

/// Errors that can occur during HealthKit operations
enum HealthServiceError: Error, LocalizedError {
    case healthKitNotAvailable
    case authorizationDenied
    case authorizationNotDetermined
    case fetchFailed(underlying: Error)
    case noRouteData

    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device."
        case .authorizationDenied:
            return "Access to health data was denied. Please enable access in Settings."
        case .authorizationNotDetermined:
            return "Health data access has not been determined."
        case .fetchFailed(let error):
            return "Failed to fetch health data: \(error.localizedDescription)"
        case .noRouteData:
            return "No route data available for this workout."
        }
    }
}
