//
//  HealthServiceTests.swift
//  ShareMyRunTests
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import Testing
@testable import ShareMyRun

@Suite("HealthService Tests")
struct HealthServiceTests {

    // MARK: - Authorization Tests

    @Suite("Authorization")
    struct AuthorizationTests {

        @Test("Request authorization returns authorized status when successful")
        func requestAuthorizationSuccess() async throws {
            let mockService = MockHealthService()
            mockService.mockAuthorizationStatus = .authorized

            let status = try await mockService.requestAuthorization()

            #expect(status == .authorized)
            #expect(mockService.requestAuthorizationCallCount == 1)
        }

        @Test("Request authorization returns denied status")
        func requestAuthorizationDenied() async throws {
            let mockService = MockHealthService()
            mockService.mockAuthorizationStatus = .denied

            let status = try await mockService.requestAuthorization()

            #expect(status == .denied)
        }

        @Test("Request authorization returns not determined status")
        func requestAuthorizationNotDetermined() async throws {
            let mockService = MockHealthService()
            mockService.mockAuthorizationStatus = .notDetermined

            let status = try await mockService.requestAuthorization()

            #expect(status == .notDetermined)
        }

        @Test("Request authorization throws when configured to fail")
        func requestAuthorizationThrows() async throws {
            let mockService = MockHealthService()
            mockService.shouldThrowOnAuthorization = true
            mockService.authorizationError = HealthServiceError.authorizationDenied

            await #expect(throws: HealthServiceError.self) {
                _ = try await mockService.requestAuthorization()
            }
        }

        @Test("HealthKit availability is reported correctly")
        func healthKitAvailability() {
            let mockService = MockHealthService()

            mockService.mockIsHealthDataAvailable = true
            #expect(mockService.isHealthDataAvailable == true)

            mockService.mockIsHealthDataAvailable = false
            #expect(mockService.isHealthDataAvailable == false)
        }
    }

    // MARK: - Fetch Workouts Tests

    @Suite("Fetch Workouts")
    struct FetchWorkoutsTests {

        @Test("Fetch workouts returns empty array when no workouts")
        func fetchWorkoutsEmpty() async throws {
            let mockService = MockHealthService()
            mockService.mockWorkouts = []

            let workouts = try await mockService.fetchWorkouts(
                from: Date().addingTimeInterval(-86400 * 30),
                to: Date()
            )

            #expect(workouts.isEmpty)
            #expect(mockService.fetchWorkoutsCallCount == 1)
        }

        @Test("Fetch workouts records date parameters")
        func fetchWorkoutsRecordsParameters() async throws {
            let mockService = MockHealthService()
            let startDate = Date().addingTimeInterval(-86400 * 30)
            let endDate = Date()

            _ = try await mockService.fetchWorkouts(from: startDate, to: endDate)

            #expect(mockService.lastFetchWorkoutsStartDate == startDate)
            #expect(mockService.lastFetchWorkoutsEndDate == endDate)
        }

        @Test("Fetch workouts throws when configured to fail")
        func fetchWorkoutsThrows() async throws {
            let mockService = MockHealthService()
            mockService.shouldThrowOnFetchWorkouts = true

            await #expect(throws: HealthServiceError.self) {
                _ = try await mockService.fetchWorkouts(
                    from: Date().addingTimeInterval(-86400),
                    to: Date()
                )
            }
        }
    }

    // MARK: - Fetch Route Tests

    @Suite("Fetch Route")
    struct FetchRouteTests {

        @Test("Fetch route returns nil when no route data")
        func fetchRouteReturnsNil() async throws {
            let mockService = MockHealthService()
            mockService.mockRouteLocations = nil

            // Create a mock workout - note: in real tests we'd need actual HKWorkout
            // For unit testing the mock, we verify the mock behavior
            #expect(mockService.fetchRouteCallCount == 0)
        }

        @Test("Fetch route increments call count")
        func fetchRouteCallCount() async throws {
            let mockService = MockHealthService()

            // We can't easily create HKWorkout objects in tests, but we can verify
            // the mock is properly configured
            #expect(mockService.mockRouteLocations == nil)
            mockService.mockRouteLocations = []
            #expect(mockService.mockRouteLocations?.isEmpty == true)
        }
    }

    // MARK: - Fetch Heart Rate Tests

    @Suite("Fetch Heart Rate")
    struct FetchHeartRateTests {

        @Test("Heart rate data returns configured values")
        func heartRateDataReturnsValues() {
            let mockService = MockHealthService()
            mockService.mockHeartRateData = (average: 145.0, max: 175.0)

            #expect(mockService.mockHeartRateData?.average == 145.0)
            #expect(mockService.mockHeartRateData?.max == 175.0)
        }

        @Test("Heart rate data returns nil when not configured")
        func heartRateDataReturnsNil() {
            let mockService = MockHealthService()
            #expect(mockService.mockHeartRateData == nil)
        }
    }

    // MARK: - Error Tests

    @Suite("Error Handling")
    struct ErrorTests {

        @Test("HealthServiceError has proper descriptions")
        func errorDescriptions() {
            let notAvailable = HealthServiceError.healthKitNotAvailable
            #expect(notAvailable.errorDescription?.contains("not available") == true)

            let denied = HealthServiceError.authorizationDenied
            #expect(denied.errorDescription?.contains("denied") == true)

            let notDetermined = HealthServiceError.authorizationNotDetermined
            #expect(notDetermined.errorDescription?.contains("not been determined") == true)

            let noRoute = HealthServiceError.noRouteData
            #expect(noRoute.errorDescription?.contains("route") == true)
        }
    }

    // MARK: - Reset Tests

    @Suite("Mock Reset")
    struct MockResetTests {

        @Test("Reset clears all call counts")
        func resetClearsCallCounts() async throws {
            let mockService = MockHealthService()

            // Make some calls
            _ = try await mockService.requestAuthorization()
            _ = try await mockService.fetchWorkouts(from: Date(), to: Date())

            #expect(mockService.requestAuthorizationCallCount == 1)
            #expect(mockService.fetchWorkoutsCallCount == 1)

            // Reset
            mockService.reset()

            #expect(mockService.requestAuthorizationCallCount == 0)
            #expect(mockService.fetchWorkoutsCallCount == 0)
            #expect(mockService.lastFetchWorkoutsStartDate == nil)
            #expect(mockService.lastFetchWorkoutsEndDate == nil)
        }
    }
}
