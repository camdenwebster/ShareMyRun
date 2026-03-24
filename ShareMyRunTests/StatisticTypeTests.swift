//
//  StatisticTypeTests.swift
//  ShareMyRunTests
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import Testing
@testable import ShareMyRun

@Suite("StatisticType Tests")
struct StatisticTypeTests {

    // MARK: - Display Properties Tests

    @Suite("Display Properties")
    struct DisplayPropertiesTests {

        @Test("All statistic types have display names")
        func allTypesHaveDisplayNames() {
            for stat in StatisticType.allCases {
                #expect(!stat.displayName.isEmpty)
            }
        }

        @Test("All statistic types have icon names")
        func allTypesHaveIconNames() {
            for stat in StatisticType.allCases {
                #expect(!stat.iconName.isEmpty)
            }
        }

        @Test("Common statistics returns expected types")
        func commonStatisticsReturnsExpected() {
            let common = StatisticType.commonStatistics
            #expect(common.contains(.distance))
            #expect(common.contains(.duration))
            #expect(common.contains(.pace))
            #expect(common.contains(.gradeAdjustedPace))
            #expect(common.contains(.startTime))
        }

        @Test("Advanced statistics returns expected types")
        func advancedStatisticsReturnsExpected() {
            let advanced = StatisticType.advancedStatistics
            #expect(advanced.contains(.calories))
            #expect(advanced.contains(.averageHeartRate))
            #expect(advanced.contains(.maxHeartRate))
            #expect(advanced.contains(.elevationGain))
        }
    }

    // MARK: - Formatting Tests

    @Suite("Formatting")
    struct FormattingTests {

        @Test("Distance formats correctly")
        func distanceFormatsCorrectly() {
            // 5 miles in meters
            let meters: Double = 5 * 1609.344
            let result = StatisticType.distance.format(value: meters)
            #expect(result.contains("5.00"))
            #expect(result.contains("mi"))
        }

        @Test("Distance formats large values with one decimal")
        func distanceFormatsLargeValues() {
            // 15 miles in meters
            let meters: Double = 15 * 1609.344
            let result = StatisticType.distance.format(value: meters)
            #expect(result.contains("15.0"))
        }

        @Test("Duration formats short times correctly")
        func durationFormatsShortTimes() {
            let seconds: TimeInterval = 1865 // 31:05
            let result = StatisticType.duration.format(value: seconds)
            #expect(result == "31:05")
        }

        @Test("Duration formats long times correctly")
        func durationFormatsLongTimes() {
            let seconds: TimeInterval = 7325 // 2:02:05
            let result = StatisticType.duration.format(value: seconds)
            #expect(result == "2:02:05")
        }

        @Test("Pace formats correctly")
        func paceFormatsCorrectly() {
            // 8:00/mile = 480 seconds/1609.344m
            let secondsPerMeter = 480.0 / 1609.344
            let result = StatisticType.pace.format(value: secondsPerMeter)
            #expect(result.contains("8:00"))
            #expect(result.contains("/mi"))
        }

        @Test("Grade adjusted pace formats correctly")
        func gradeAdjustedPaceFormatsCorrectly() {
            // 7:45/mile = 465 seconds/1609.344m
            let secondsPerMeter = 465.0 / 1609.344
            let result = StatisticType.gradeAdjustedPace.format(value: secondsPerMeter)
            #expect(result.contains("7:45"))
            #expect(result.contains("/mi"))
        }

        @Test("Calories formats correctly")
        func caloriesFormatsCorrectly() {
            let result = StatisticType.calories.format(value: 523.7)
            #expect(result == "524 cal")
        }

        @Test("Heart rate formats correctly")
        func heartRateFormatsCorrectly() {
            let result = StatisticType.averageHeartRate.format(value: 145.5)
            #expect(result == "146 bpm")
        }

        @Test("Elevation formats correctly")
        func elevationFormatsCorrectly() {
            // 100 meters = ~328 feet
            let result = StatisticType.elevationGain.format(value: 100.0)
            #expect(result.contains("328"))
            #expect(result.contains("ft"))
        }

        @Test("Start time formats correctly")
        func startTimeFormatsCorrectly() {
            var components = DateComponents()
            components.hour = 14
            components.minute = 30
            let date = Calendar.current.date(from: components)!

            let result = StatisticType.startTime.format(value: date)
            #expect(result.contains("2:30") || result.contains("14:30"))
        }

        @Test("Nil value returns N/A")
        func nilValueReturnsNA() {
            let result = StatisticType.distance.format(value: nil)
            #expect(result == "N/A")
        }
    }

    // MARK: - Value Extraction Tests

    @Suite("Value Extraction")
    struct ValueExtractionTests {

        @Test("getValue extracts distance correctly")
        func getValueExtractsDistance() {
            let workout = Workout(
                healthKitID: "test",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                distance: 5000,
                duration: 3600
            )

            let value = StatisticType.distance.getValue(from: workout)
            #expect(value as? Double == 5000)
        }

        @Test("getValue returns nil for missing data")
        func getValueReturnsNilForMissingData() {
            let workout = Workout(
                healthKitID: "test",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                duration: 3600
            )

            let value = StatisticType.calories.getValue(from: workout)
            #expect(value == nil)
        }

        @Test("isAvailable returns correct values")
        func isAvailableReturnsCorrectValues() {
            let workout = Workout(
                healthKitID: "test",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                distance: 5000,
                duration: 3600,
                averageHeartRate: 145,
                elevationGain: 50
            )

            #expect(StatisticType.distance.isAvailable(for: workout) == true)
            #expect(StatisticType.duration.isAvailable(for: workout) == true)
            #expect(StatisticType.averageHeartRate.isAvailable(for: workout) == true)
            #expect(StatisticType.gradeAdjustedPace.isAvailable(for: workout) == false)
            #expect(StatisticType.calories.isAvailable(for: workout) == false)
            #expect(StatisticType.elevationGain.isAvailable(for: workout) == true)
            #expect(StatisticType.startTime.isAvailable(for: workout) == true) // Always available
        }

        @Test("Grade adjusted pace available when distance pace and elevation exist")
        func gradeAdjustedPaceAvailability() {
            let workout = Workout(
                healthKitID: "grade-adjusted",
                type: .running,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                distance: 5000,
                duration: 3600,
                averagePace: 480.0 / 1609.344,
                elevationGain: 120
            )

            #expect(StatisticType.gradeAdjustedPace.isAvailable(for: workout) == true)
            #expect(StatisticType.gradeAdjustedPace.getValue(from: workout) as? Double != nil)
        }
    }
}
