//
//  Workout.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import SwiftData
import CoreLocation

/// Represents the type of workout activity
enum WorkoutType: String, Codable, CaseIterable, Identifiable {
    case running
    case cycling
    case swimming
    case hiking
    case walking
    case other

    var id: String { rawValue }

    /// Display name for the workout type
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .walking: return "Walking"
        case .other: return "Other"
        }
    }

    /// SF Symbol name for the workout type
    var iconName: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .hiking: return "figure.hiking"
        case .walking: return "figure.walk"
        case .other: return "figure.mixed.cardio"
        }
    }
}

/// Represents a single coordinate point in a route
/// Stored as simple latitude/longitude for SwiftData compatibility
struct RouteCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
    }

    /// Converts back to CLLocationCoordinate2D for MapKit usage
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// SwiftData model representing a workout imported from HealthKit
@Model
final class Workout {
    /// Unique identifier from HealthKit
    @Attribute(.unique) var healthKitID: String

    /// Type of workout activity
    var type: WorkoutType

    /// When the workout started
    var startDate: Date

    /// When the workout ended
    var endDate: Date

    /// Total distance in meters
    var distance: Double?

    /// Duration in seconds
    var duration: TimeInterval

    /// Route coordinates as encoded JSON data
    /// Using Data for SwiftData compatibility with complex types
    var routeData: Data?

    /// Total calories burned
    var calories: Double?

    /// Average heart rate in BPM
    var averageHeartRate: Double?

    /// Maximum heart rate in BPM
    var maxHeartRate: Double?

    /// Average pace in seconds per meter (for display, convert to min/mile or min/km)
    var averagePace: Double?

    /// Total elevation gain in meters
    var elevationGain: Double?

    /// When this workout was imported into the app
    var importedAt: Date

    /// The share configuration for this workout (if any)
    @Relationship(deleteRule: .cascade, inverse: \ShareConfiguration.workout)
    var shareConfiguration: ShareConfiguration?

    // MARK: - Computed Properties

    /// Route coordinates decoded from stored data
    var routeCoordinates: [RouteCoordinate]? {
        get {
            guard let data = routeData else { return nil }
            return try? JSONDecoder().decode([RouteCoordinate].self, from: data)
        }
        set {
            routeData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Whether this workout has route data for map display
    var hasRoute: Bool {
        guard let coordinates = routeCoordinates else { return false }
        return coordinates.count >= 2
    }

    /// Distance in miles
    var distanceInMiles: Double? {
        guard let distance = distance else { return nil }
        return distance / 1609.344
    }

    /// Distance in kilometers
    var distanceInKilometers: Double? {
        guard let distance = distance else { return nil }
        return distance / 1000.0
    }

    /// Duration formatted as HH:MM:SS or MM:SS
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Average pace formatted as MM:SS per mile
    var formattedPacePerMile: String? {
        guard let pace = averagePace, pace > 0 else { return nil }
        // pace is seconds per meter, convert to seconds per mile
        let secondsPerMile = pace * 1609.344
        let minutes = Int(secondsPerMile) / 60
        let seconds = Int(secondsPerMile) % 60
        return String(format: "%d:%02d /mi", minutes, seconds)
    }

    /// Average pace formatted as MM:SS per kilometer
    var formattedPacePerKilometer: String? {
        guard let pace = averagePace, pace > 0 else { return nil }
        // pace is seconds per meter, convert to seconds per km
        let secondsPerKm = pace * 1000.0
        let minutes = Int(secondsPerKm) / 60
        let seconds = Int(secondsPerKm) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    /// Grade adjusted pace in seconds per meter.
    /// Uses a simple grade correction based on net elevation gain and total distance.
    var gradeAdjustedPace: Double? {
        guard
            let pace = averagePace,
            pace > 0,
            let distance,
            distance > 0,
            let elevationGain
        else {
            return nil
        }

        let grade = elevationGain / distance
        let adjustment = min(max(1.0 + (grade * 0.035), 0.75), 1.25)
        return pace / adjustment
    }

    // MARK: - Initialization

    init(
        healthKitID: String,
        type: WorkoutType,
        startDate: Date,
        endDate: Date,
        distance: Double? = nil,
        duration: TimeInterval,
        routeCoordinates: [RouteCoordinate]? = nil,
        calories: Double? = nil,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        averagePace: Double? = nil,
        elevationGain: Double? = nil
    ) {
        self.healthKitID = healthKitID
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.distance = distance
        self.duration = duration
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.averagePace = averagePace
        self.elevationGain = elevationGain
        self.importedAt = Date()

        // Encode route coordinates
        if let coordinates = routeCoordinates {
            self.routeData = try? JSONEncoder().encode(coordinates)
        }
    }
}
