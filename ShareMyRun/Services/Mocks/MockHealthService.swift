//
//  MockHealthService.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import HealthKit
import CoreLocation

/// Mock implementation of HealthServiceProtocol for testing
/// Uses nonisolated(unsafe) for test-only mutable state to avoid MainActor restrictions in tests
final class MockHealthService: HealthServiceProtocol, @unchecked Sendable {

    // MARK: - Configuration

    /// Controls whether HealthKit is reported as available
    nonisolated(unsafe) var mockIsHealthDataAvailable: Bool = true

    /// The authorization status to return
    nonisolated(unsafe) var mockAuthorizationStatus: HealthKitAuthorizationStatus = .authorized

    /// Whether authorization request should throw an error
    nonisolated(unsafe) var shouldThrowOnAuthorization: Bool = false
    nonisolated(unsafe) var authorizationError: Error = HealthServiceError.authorizationDenied

    /// Workouts to return from fetch
    nonisolated(unsafe) var mockWorkouts: [HKWorkout] = []

    /// Whether workout fetch should throw an error
    nonisolated(unsafe) var shouldThrowOnFetchWorkouts: Bool = false
    nonisolated(unsafe) var fetchWorkoutsError: Error = HealthServiceError.fetchFailed(underlying: NSError(domain: "test", code: -1))

    /// Route locations to return
    nonisolated(unsafe) var mockRouteLocations: [CLLocation]? = nil

    /// Whether route fetch should throw an error
    nonisolated(unsafe) var shouldThrowOnFetchRoute: Bool = false
    nonisolated(unsafe) var fetchRouteError: Error = HealthServiceError.noRouteData

    /// Heart rate data to return
    nonisolated(unsafe) var mockHeartRateData: (average: Double, max: Double)? = nil

    /// Whether heart rate fetch should throw an error
    nonisolated(unsafe) var shouldThrowOnFetchHeartRate: Bool = false
    nonisolated(unsafe) var fetchHeartRateError: Error = HealthServiceError.fetchFailed(underlying: NSError(domain: "test", code: -1))

    // MARK: - Call Tracking

    /// Number of times requestAuthorization was called
    nonisolated(unsafe) private(set) var requestAuthorizationCallCount = 0

    /// Number of times fetchWorkouts was called
    nonisolated(unsafe) private(set) var fetchWorkoutsCallCount = 0

    /// Parameters passed to fetchWorkouts
    nonisolated(unsafe) private(set) var lastFetchWorkoutsStartDate: Date?
    nonisolated(unsafe) private(set) var lastFetchWorkoutsEndDate: Date?

    /// Number of times fetchRoute was called
    nonisolated(unsafe) private(set) var fetchRouteCallCount = 0

    /// Number of times fetchHeartRateData was called
    nonisolated(unsafe) private(set) var fetchHeartRateCallCount = 0

    // MARK: - HealthServiceProtocol

    var isHealthDataAvailable: Bool {
        mockIsHealthDataAvailable
    }

    func requestAuthorization() async throws -> HealthKitAuthorizationStatus {
        requestAuthorizationCallCount += 1

        if shouldThrowOnAuthorization {
            throw authorizationError
        }

        return mockAuthorizationStatus
    }

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        fetchWorkoutsCallCount += 1
        lastFetchWorkoutsStartDate = startDate
        lastFetchWorkoutsEndDate = endDate

        if shouldThrowOnFetchWorkouts {
            throw fetchWorkoutsError
        }

        return mockWorkouts
    }

    func fetchRoute(for workout: HKWorkout) async throws -> [CLLocation]? {
        fetchRouteCallCount += 1

        if shouldThrowOnFetchRoute {
            throw fetchRouteError
        }

        return mockRouteLocations
    }

    func fetchHeartRateData(for workout: HKWorkout) async throws -> (average: Double, max: Double)? {
        fetchHeartRateCallCount += 1

        if shouldThrowOnFetchHeartRate {
            throw fetchHeartRateError
        }

        return mockHeartRateData
    }

    // MARK: - Helpers

    /// Resets all call counts and tracking data
    func reset() {
        requestAuthorizationCallCount = 0
        fetchWorkoutsCallCount = 0
        lastFetchWorkoutsStartDate = nil
        lastFetchWorkoutsEndDate = nil
        fetchRouteCallCount = 0
        fetchHeartRateCallCount = 0
    }
}
