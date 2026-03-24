//
//  SharePrivacySettings.swift
//  ShareMyRun
//
//  Created by Codex on 3/24/26.
//

import CoreLocation
import Foundation

/// Available distances for hiding the real route start and end points.
enum RouteRedactionDistance: Int, Codable, CaseIterable, Identifiable {
    case eighthMile
    case quarterMile
    case halfMile
    case oneMile

    static let defaultValue: Self = .quarterMile

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .eighthMile:
            return "1/8 mi"
        case .quarterMile:
            return "1/4 mi"
        case .halfMile:
            return "1/2 mi"
        case .oneMile:
            return "1 mi"
        }
    }

    var measurement: Measurement<UnitLength> {
        switch self {
        case .eighthMile:
            return .init(value: 0.125, unit: .miles)
        case .quarterMile:
            return .init(value: 0.25, unit: .miles)
        case .halfMile:
            return .init(value: 0.5, unit: .miles)
        case .oneMile:
            return .init(value: 1, unit: .miles)
        }
    }

    var meters: CLLocationDistance {
        measurement.converted(to: .meters).value
    }

    var sliderValue: Double {
        Double(rawValue)
    }

    init(sliderValue: Double) {
        let clampedValue = Int(sliderValue.rounded())
        self = Self(rawValue: min(max(clampedValue, 0), Self.allCases.count - 1)) ?? .defaultValue
    }
}

enum SharePrivacySettings {
    static let routeRedactionDistanceKey = "sharePrivacy.routeRedactionDistance"
    static let removeWatermarkKey = "sharePrivacy.removeWatermark"

    static var routeRedactionDistance: RouteRedactionDistance {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: routeRedactionDistanceKey) != nil else {
                return .defaultValue
            }
            return RouteRedactionDistance(sliderValue: defaults.double(forKey: routeRedactionDistanceKey))
        }
        set {
            UserDefaults.standard.set(newValue.sliderValue, forKey: routeRedactionDistanceKey)
        }
    }

    static var removeWatermark: Bool {
        get {
            UserDefaults.standard.bool(forKey: removeWatermarkKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: removeWatermarkKey)
        }
    }
}
