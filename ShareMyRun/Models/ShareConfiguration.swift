//
//  ShareConfiguration.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import CoreLocation
import SwiftData
import SwiftUI

/// Represents the type of background for the shareable image
enum BackgroundType: String, Codable, CaseIterable, Identifiable {
    case routeMap
    case lastPhoto
    case selectedPhoto

    var id: String { rawValue }

    /// Display name for the background type
    var displayName: String {
        switch self {
        case .routeMap: return "Route Map"
        case .lastPhoto: return "Last Photo"
        case .selectedPhoto: return "Choose Photo"
        }
    }

    /// SF Symbol name for the background type
    var iconName: String {
        switch self {
        case .routeMap: return "map"
        case .lastPhoto: return "photo.on.rectangle"
        case .selectedPhoto: return "photo.badge.plus"
        }
    }

}

/// Represents the position of text overlay on the shareable image
enum TextPosition: String, Codable, CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center

    var id: String { rawValue }

    /// Display name for the text position
    var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .center: return "Center"
        }
    }

    /// Alignment for SwiftUI
    var alignment: Alignment {
        switch self {
        case .topLeft: return .topLeading
        case .topRight: return .topTrailing
        case .bottomLeft: return .bottomLeading
        case .bottomRight: return .bottomTrailing
        case .center: return .center
        }
    }

}

/// Available fonts for the statistics overlay
enum OverlayFont: String, Codable, CaseIterable, Identifiable {
    case system = "SF Pro"
    case systemRounded = "SF Pro Rounded"
    case newYork = "New York"
    case menlo = "Menlo"
    case helveticaNeue = "Helvetica Neue"
    case avenir = "Avenir"
    case georgia = "Georgia"
    case futura = "Futura"

    var id: String { rawValue }

    /// The actual font name to use with UIFont/Font
    var fontName: String {
        switch self {
        case .system: return ".AppleSystemUIFont"
        case .systemRounded: return ".AppleSystemUIFontRounded"
        case .newYork: return "NewYork-Regular"
        case .menlo: return "Menlo"
        case .helveticaNeue: return "HelveticaNeue"
        case .avenir: return "Avenir"
        case .georgia: return "Georgia"
        case .futura: return "Futura-Medium"
        }
    }

    /// Display name for the font
    var displayName: String {
        switch self {
        case .system:
            return "SF Pro"
        case .systemRounded:
            return "SF Rounded"
        case .newYork:
            return "New York"
        case .menlo:
            return "Menlo"
        case .helveticaNeue:
            return "Helvetica Neue"
        case .avenir:
            return "Avenir"
        case .georgia:
            return "Georgia"
        case .futura:
            return "Futura"
        }
    }

    /// Preview font used in SwiftUI controls
    var previewFont: Font {
        switch self {
        case .system:
            return .system(size: 16, weight: .regular, design: .default)
        case .systemRounded:
            return .system(size: 16, weight: .regular, design: .rounded)
        default:
            return .custom(fontName, size: 16)
        }
    }
}

/// Available distances for hiding the real route start and end points.
enum RouteRedactionDistance: String, Codable, CaseIterable, Identifiable {
    case eighthMile
    case quarterMile
    case halfMile
    case oneMile

    var id: String { rawValue }

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
}

/// SwiftData model storing the user's sharing preferences for a workout
@Model
final class ShareConfiguration {
    /// The workout this configuration belongs to
    var workout: Workout?

    /// Selected statistics to display (stored as raw values)
    var selectedStatisticsRaw: [String]

    /// Featured statistic displayed larger on the opposite side
    var featuredStatisticRaw: String = StatisticType.distance.rawValue

    /// Type of background to use
    var backgroundType: BackgroundType

    /// Selected font for text overlay
    var font: OverlayFont

    /// Font size in points (12-32)
    var fontSize: CGFloat

    /// Text color as hex string
    var textColorHex: String

    /// Position of the text overlay
    var textPosition: TextPosition

    /// Stored raw value for how much route data is hidden at the start and end.
    var routeRedactionDistanceRaw: String

    /// Path to selected photo (if backgroundType is selectedPhoto)
    var selectedPhotoIdentifier: String?

    /// When this configuration was last modified
    var lastModified: Date

    // MARK: - Computed Properties

    /// Selected statistics as StatisticType array
    var selectedStatistics: [StatisticType] {
        get {
            selectedStatisticsRaw.compactMap { StatisticType(rawValue: $0) }
        }
        set {
            selectedStatisticsRaw = newValue.map { $0.rawValue }
        }
    }

    /// Featured statistic as StatisticType
    var featuredStatistic: StatisticType {
        get {
            StatisticType(rawValue: featuredStatisticRaw) ?? .distance
        }
        set {
            featuredStatisticRaw = newValue.rawValue
        }
    }

    /// Text color as SwiftUI Color
    var textColor: Color {
        get {
            Color(hex: textColorHex) ?? .white
        }
        set {
            textColorHex = newValue.toHex() ?? "#FFFFFF"
        }
    }

    /// Distance hidden from both the start and end of the route image.
    var routeRedactionDistance: RouteRedactionDistance {
        get {
            RouteRedactionDistance(rawValue: routeRedactionDistanceRaw) ?? .quarterMile
        }
        set {
            routeRedactionDistanceRaw = newValue.rawValue
        }
    }

    // MARK: - Initialization

    init(
        workout: Workout? = nil,
        selectedStatistics: [StatisticType] = [.distance, .duration, .pace],
        backgroundType: BackgroundType = .routeMap,
        font: OverlayFont = .system,
        fontSize: CGFloat = 18,
        textColor: Color = .white,
        textPosition: TextPosition = .bottomLeft,
        routeRedactionDistance: RouteRedactionDistance = .quarterMile
    ) {
        self.workout = workout
        self.selectedStatisticsRaw = selectedStatistics.map { $0.rawValue }
        self.featuredStatisticRaw = StatisticType.distance.rawValue
        self.backgroundType = backgroundType
        self.font = font
        self.fontSize = fontSize
        self.textColorHex = textColor.toHex() ?? "#FFFFFF"
        self.textPosition = textPosition
        self.routeRedactionDistanceRaw = routeRedactionDistance.rawValue
        self.lastModified = Date()
    }

    // MARK: - Default Configuration

    /// Creates a default configuration with sensible defaults
    static func defaultConfiguration(for workout: Workout? = nil) -> ShareConfiguration {
        ShareConfiguration(
            workout: workout,
            selectedStatistics: [.distance, .duration, .pace],
            backgroundType: workout?.hasRoute == true ? .routeMap : .lastPhoto,
            font: .system,
            fontSize: 18,
            textColor: .white,
            textPosition: .bottomLeft,
            routeRedactionDistance: .quarterMile
        )
    }
}

// MARK: - Color Extensions

extension Color {
    /// Initialize Color from hex string
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    /// Convert Color to hex string
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else {
            return nil
        }

        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0

        return String(format: "#%02X%02X%02X",
                      Int(r * 255),
                      Int(g * 255),
                      Int(b * 255))
    }
}
