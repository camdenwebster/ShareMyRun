//
//  StatisticType.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation

/// Represents the types of statistics that can be displayed on a shareable image
enum StatisticType: String, Codable, CaseIterable, Identifiable {
    case distance
    case duration
    case pace
    case gradeAdjustedPace
    case startTime
    case calories
    case averageHeartRate
    case maxHeartRate
    case elevationGain
    case effort

    var id: String { rawValue }

    /// Display name shown in the UI
    var displayName: String {
        switch self {
        case .distance: return "Distance"
        case .duration: return "Duration"
        case .pace: return "Pace"
        case .gradeAdjustedPace: return "Grade Adjusted Pace"
        case .startTime: return "Start Time"
        case .calories: return "Calories"
        case .averageHeartRate: return "Avg Heart Rate"
        case .maxHeartRate: return "Max Heart Rate"
        case .elevationGain: return "Elevation Gain"
        case .effort: return "Effort"
        }
    }

    /// Unit label for the statistic
    var unit: String {
        switch self {
        case .distance: return "mi" // Will be configurable for km
        case .duration: return ""
        case .pace: return "/mi" // Will be configurable for /km
        case .gradeAdjustedPace: return "/mi"
        case .startTime: return ""
        case .calories: return "cal"
        case .averageHeartRate: return "bpm"
        case .maxHeartRate: return "bpm"
        case .elevationGain: return "ft" // Will be configurable for m
        case .effort: return ""
        }
    }

    /// SF Symbol name for the statistic
    var iconName: String {
        switch self {
        case .distance: return "point.topleft.down.to.point.bottomright.curvepath"
        case .duration: return "timer"
        case .pace: return "speedometer"
        case .gradeAdjustedPace: return "figure.run"
        case .startTime: return "clock"
        case .calories: return "flame"
        case .averageHeartRate: return "heart"
        case .maxHeartRate: return "heart.fill"
        case .elevationGain: return "mountain.2"
        case .effort: return "figure.run.circle"
        }
    }

    // MARK: - Formatting

    /// Formats a value for display
    /// - Parameters:
    ///   - value: The raw value to format
    ///   - workout: Optional workout for context-dependent formatting
    /// - Returns: Formatted string with unit
    func format(value: Any?, from workout: Workout? = nil) -> String {
        guard let value = value else {
            return "N/A"
        }

        switch self {
        case .distance:
            return formatDistance(value)
        case .duration:
            return formatDuration(value)
        case .pace:
            return formatPace(value)
        case .gradeAdjustedPace:
            return formatPace(value)
        case .startTime:
            return formatStartTime(value)
        case .calories:
            return formatCalories(value)
        case .averageHeartRate, .maxHeartRate:
            return formatHeartRate(value)
        case .elevationGain:
            return formatElevation(value)
        case .effort:
            return formatEffort(value)
        }
    }

    /// Gets the value for this statistic from a workout
    /// - Parameter workout: The workout to extract the value from
    /// - Returns: The raw value, or nil if unavailable
    func getValue(from workout: Workout) -> Any? {
        switch self {
        case .distance:
            return workout.distance
        case .duration:
            return workout.duration
        case .pace:
            return workout.averagePace
        case .gradeAdjustedPace:
            return workout.gradeAdjustedPace
        case .startTime:
            return workout.startDate
        case .calories:
            return workout.calories
        case .averageHeartRate:
            return workout.averageHeartRate
        case .maxHeartRate:
            return workout.maxHeartRate
        case .elevationGain:
            return workout.elevationGain
        case .effort:
            // Effort could be calculated from heart rate zones or perceived exertion
            // For now, return nil (future feature)
            return nil
        }
    }

    /// Checks if this statistic is available for a given workout
    /// - Parameter workout: The workout to check
    /// - Returns: true if the statistic has a value
    func isAvailable(for workout: Workout) -> Bool {
        switch self {
        case .distance:
            return workout.distance != nil
        case .duration:
            return workout.duration > 0
        case .pace:
            return workout.averagePace != nil
        case .gradeAdjustedPace:
            return workout.gradeAdjustedPace != nil
        case .startTime:
            return true // Always available
        case .calories:
            return workout.calories != nil
        case .averageHeartRate:
            return workout.averageHeartRate != nil
        case .maxHeartRate:
            return workout.maxHeartRate != nil
        case .elevationGain:
            return workout.elevationGain != nil
        case .effort:
            return false // Not yet implemented
        }
    }

    // MARK: - Private Formatting Helpers

    private func formatDistance(_ value: Any) -> String {
        guard let meters = value as? Double else { return "N/A" }
        let miles = meters / 1609.344
        if miles >= 10 {
            return String(format: "%.1f %@", miles, unit)
        } else {
            return String(format: "%.2f %@", miles, unit)
        }
    }

    private func formatDuration(_ value: Any) -> String {
        guard let seconds = value as? TimeInterval else { return "N/A" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func formatPace(_ value: Any) -> String {
        guard let secondsPerMeter = value as? Double, secondsPerMeter > 0 else {
            return "N/A"
        }
        // Convert to seconds per mile
        let secondsPerMile = secondsPerMeter * 1609.344
        let minutes = Int(secondsPerMile) / 60
        let seconds = Int(secondsPerMile) % 60
        return String(format: "%d:%02d %@", minutes, seconds, unit)
    }

    private func formatStartTime(_ value: Any) -> String {
        guard let date = value as? Date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatCalories(_ value: Any) -> String {
        guard let calories = value as? Double else { return "N/A" }
        return String(format: "%.0f %@", calories, unit)
    }

    private func formatHeartRate(_ value: Any) -> String {
        guard let bpm = value as? Double else { return "N/A" }
        return String(format: "%.0f %@", bpm, unit)
    }

    private func formatElevation(_ value: Any) -> String {
        guard let meters = value as? Double else { return "N/A" }
        let feet = meters * 3.28084
        return String(format: "%.0f %@", feet, unit)
    }

    private func formatEffort(_ value: Any) -> String {
        // Future: Could be 1-10 scale or descriptive (Easy, Moderate, Hard)
        return "N/A"
    }
}

// MARK: - Convenience Extensions

extension StatisticType {
    /// Returns all statistics that are commonly available for most workouts
    static var commonStatistics: [StatisticType] {
        [.distance, .duration, .pace, .gradeAdjustedPace, .startTime]
    }

    /// Returns statistics that require additional data (heart rate monitor, etc.)
    static var advancedStatistics: [StatisticType] {
        [.calories, .averageHeartRate, .maxHeartRate, .elevationGain, .effort]
    }
}
