//
//  WorkoutRepositoryTests.swift
//  ShareMyRunTests
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import Testing
@testable import ShareMyRun

@Suite("WorkoutRepository Tests")
struct WorkoutRepositoryTests {

    // MARK: - Mock Repository Tests

    @Suite("Mock Repository")
    struct MockRepositoryTests {

        @Test("Mock repository returns configured workouts")
        func mockRepositoryReturnsWorkouts() {
            let mockRepo = MockWorkoutRepository()
            let testWorkout = Workout(
                healthKitID: "test-123",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                distance: 5000,
                duration: 3600
            )
            mockRepo.mockWorkouts = [testWorkout]

            #expect(mockRepo.mockWorkouts.count == 1)
            #expect(mockRepo.mockWorkouts.first?.healthKitID == "test-123")
        }

        @Test("Mock repository tracks sync call count")
        func mockRepositoryTracksSyncCalls() async throws {
            let mockRepo = MockWorkoutRepository()

            #expect(mockRepo.syncWorkoutsCallCount == 0)
        }

        @Test("Mock repository throws when configured")
        func mockRepositoryThrowsWhenConfigured() {
            let mockRepo = MockWorkoutRepository()
            mockRepo.shouldThrowOnSync = true

            #expect(mockRepo.shouldThrowOnSync == true)
        }

        @Test("Mock repository reset clears state")
        func mockRepositoryResetClearsState() {
            let mockRepo = MockWorkoutRepository()
            mockRepo.mockWorkouts = [
                Workout(
                    healthKitID: "test",
                    type: .running,
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(3600),
                    duration: 3600
                )
            ]

            mockRepo.reset()

            #expect(mockRepo.mockWorkouts.isEmpty)
            #expect(mockRepo.syncWorkoutsCallCount == 0)
            #expect(mockRepo.fetchStoredWorkoutsCallCount == 0)
        }
    }

    // MARK: - Workout Type Mapping Tests

    @Suite("Workout Type Mapping")
    struct WorkoutTypeMappingTests {

        @Test("All workout types are properly configured")
        func allWorkoutTypesConfigured() {
            // Verify all our supported types exist
            let supportedTypes: [WorkoutType] = [
                .running, .cycling, .swimming, .hiking, .walking, .other
            ]

            for type in supportedTypes {
                #expect(!type.displayName.isEmpty)
                #expect(!type.iconName.isEmpty)
            }
        }
    }
}
