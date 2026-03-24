//
//  WorkoutModelTests.swift
//  ShareMyRunTests
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import Testing
@testable import ShareMyRun

@Suite("Workout Model Tests")
struct WorkoutModelTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Workout initializes with required properties")
        func workoutInitializesWithRequiredProperties() {
            let workout = Workout(
                healthKitID: "test-123",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                duration: 3600
            )

            #expect(workout.healthKitID == "test-123")
            #expect(workout.type == .running)
            #expect(workout.duration == 3600)
        }

        @Test("Workout initializes with all optional properties")
        func workoutInitializesWithAllProperties() {
            let coordinates = [
                RouteCoordinate(latitude: 37.7749, longitude: -122.4194),
                RouteCoordinate(latitude: 37.7750, longitude: -122.4195)
            ]

            let workout = Workout(
                healthKitID: "test-456",
                type: .cycling,
                startDate: Date(),
                endDate: Date().addingTimeInterval(7200),
                distance: 10000,
                duration: 7200,
                routeCoordinates: coordinates,
                calories: 500,
                averageHeartRate: 145,
                maxHeartRate: 175,
                averagePace: 0.0006, // seconds per meter
                elevationGain: 100
            )

            #expect(workout.distance == 10000)
            #expect(workout.calories == 500)
            #expect(workout.averageHeartRate == 145)
            #expect(workout.maxHeartRate == 175)
            #expect(workout.elevationGain == 100)
            #expect(workout.hasRoute == true)
        }
    }

    // MARK: - WorkoutType Tests

    @Suite("WorkoutType")
    struct WorkoutTypeTests {

        @Test("All workout types have display names")
        func allTypesHaveDisplayNames() {
            for type in WorkoutType.allCases {
                #expect(!type.displayName.isEmpty)
            }
        }

        @Test("All workout types have icon names")
        func allTypesHaveIconNames() {
            for type in WorkoutType.allCases {
                #expect(!type.iconName.isEmpty)
            }
        }

        @Test("Workout type display names are correct")
        func displayNamesAreCorrect() {
            #expect(WorkoutType.running.displayName == "Running")
            #expect(WorkoutType.cycling.displayName == "Cycling")
            #expect(WorkoutType.swimming.displayName == "Swimming")
            #expect(WorkoutType.hiking.displayName == "Hiking")
            #expect(WorkoutType.walking.displayName == "Walking")
            #expect(WorkoutType.other.displayName == "Other")
        }
    }

    // MARK: - Route Tests

    @Suite("Route Data")
    struct RouteDataTests {

        @Test("Route coordinates encode and decode correctly")
        func routeCoordinatesEncodeDecodeCorrectly() {
            let workout = Workout(
                healthKitID: "route-test",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                duration: 3600,
                routeCoordinates: [
                    RouteCoordinate(latitude: 37.7749, longitude: -122.4194),
                    RouteCoordinate(latitude: 37.7750, longitude: -122.4195),
                    RouteCoordinate(latitude: 37.7751, longitude: -122.4196)
                ]
            )

            let decoded = workout.routeCoordinates
            #expect(decoded?.count == 3)
            #expect(decoded?.first?.latitude == 37.7749)
            #expect(decoded?.first?.longitude == -122.4194)
        }

        @Test("hasRoute returns false when no coordinates")
        func hasRouteReturnsFalseWhenNoCoordinates() {
            let workout = Workout(
                healthKitID: "no-route",
                type: .swimming,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                duration: 3600
            )

            #expect(workout.hasRoute == false)
        }

        @Test("hasRoute returns false when only one coordinate")
        func hasRouteReturnsFalseWithOneCoordinate() {
            let workout = Workout(
                healthKitID: "one-coord",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                duration: 3600,
                routeCoordinates: [RouteCoordinate(latitude: 37.7749, longitude: -122.4194)]
            )

            #expect(workout.hasRoute == false)
        }

        @Test("hasRoute returns true when multiple coordinates")
        func hasRouteReturnsTrueWithMultipleCoordinates() {
            let workout = Workout(
                healthKitID: "multi-coord",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                duration: 3600,
                routeCoordinates: [
                    RouteCoordinate(latitude: 37.7749, longitude: -122.4194),
                    RouteCoordinate(latitude: 37.7750, longitude: -122.4195)
                ]
            )

            #expect(workout.hasRoute == true)
        }
    }

    // MARK: - Computed Properties Tests

    @Suite("Computed Properties")
    struct ComputedPropertiesTests {

        @Test("Distance converts to miles correctly")
        func distanceConvertsToMiles() {
            let workout = Workout(
                healthKitID: "distance-test",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                distance: 1609.344, // 1 mile in meters
                duration: 3600
            )

            #expect(workout.distanceInMiles != nil)
            #expect(abs(workout.distanceInMiles! - 1.0) < 0.001)
        }

        @Test("Distance converts to kilometers correctly")
        func distanceConvertsToKilometers() {
            let workout = Workout(
                healthKitID: "km-test",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                distance: 1000, // 1 km in meters
                duration: 3600
            )

            #expect(workout.distanceInKilometers != nil)
            #expect(abs(workout.distanceInKilometers! - 1.0) < 0.001)
        }

        @Test("Duration formats correctly for short workouts")
        func durationFormatsForShortWorkouts() {
            let workout = Workout(
                healthKitID: "short-duration",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(1865),
                duration: 1865 // 31:05
            )

            #expect(workout.formattedDuration == "31:05")
        }

        @Test("Duration formats correctly for long workouts")
        func durationFormatsForLongWorkouts() {
            let workout = Workout(
                healthKitID: "long-duration",
                type: .cycling,
                startDate: Date(),
                endDate: Date().addingTimeInterval(7325),
                duration: 7325 // 2:02:05
            )

            #expect(workout.formattedDuration == "2:02:05")
        }

        @Test("Pace formats correctly per mile")
        func paceFormatsPerMile() {
            // 8:00/mile = 480 seconds/1609.344m = ~0.298 seconds/meter
            let secondsPerMeter = 480.0 / 1609.344

            let workout = Workout(
                healthKitID: "pace-test",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                duration: 3600,
                averagePace: secondsPerMeter
            )

            #expect(workout.formattedPacePerMile == "8:00 /mi")
        }

        @Test("Pace returns nil when no pace data")
        func paceReturnsNilWhenNoPaceData() {
            let workout = Workout(
                healthKitID: "no-pace",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                duration: 3600
            )

            #expect(workout.formattedPacePerMile == nil)
        }

        @Test("Grade adjusted pace returns adjusted value")
        func gradeAdjustedPaceReturnsAdjustedValue() {
            let basePace = 480.0 / 1609.344

            let workout = Workout(
                healthKitID: "gap-test",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                distance: 5000,
                duration: 3600,
                averagePace: basePace,
                elevationGain: 100
            )

            #expect(workout.gradeAdjustedPace != nil)
            #expect(workout.gradeAdjustedPace! < basePace)
        }
    }
}
