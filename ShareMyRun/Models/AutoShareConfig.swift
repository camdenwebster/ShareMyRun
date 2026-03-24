//
//  AutoShareConfig.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import SwiftData

/// Model for automatic sharing configuration (Pro feature - stubbed)
/// Will be used for automatic posting after workout completion
@Model
final class AutoShareConfig {
    /// Whether automatic sharing is enabled
    var isEnabled: Bool

    /// Social media destinations for automatic sharing
    var destinationsRaw: [String]

    /// Reference to the default share template to use
    var defaultTemplateID: String?

    /// How auto-share delivers content once an image is generated.
    var deliveryModeRaw: String

    /// How far back to look for completed workouts when queueing jobs.
    var lookbackWindowMinutes: Int

    /// Output format used for generated auto-share images.
    var imageFormatRaw: String

    /// Persisted queue of auto-share jobs.
    var jobsData: Data?

    /// When this configuration was last modified
    var lastModified: Date

    // MARK: - Computed Properties

    /// Destinations as enum array
    var destinations: [ShareDestination] {
        get {
            destinationsRaw.compactMap { ShareDestination(rawValue: $0) }
        }
        set {
            destinationsRaw = newValue.map { $0.rawValue }
        }
    }

    var deliveryMode: AutoShareDeliveryMode {
        get {
            AutoShareDeliveryMode(rawValue: deliveryModeRaw) ?? .queueOnly
        }
        set {
            deliveryModeRaw = newValue.rawValue
        }
    }

    var imageFormat: AutoShareImageFormat {
        get {
            AutoShareImageFormat(rawValue: imageFormatRaw) ?? .square
        }
        set {
            imageFormatRaw = newValue.rawValue
        }
    }

    var jobs: [AutoShareJob] {
        get {
            guard let jobsData else { return [] }
            return (try? JSONDecoder().decode([AutoShareJob].self, from: jobsData)) ?? []
        }
        set {
            jobsData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Initialization

    init(
        isEnabled: Bool = false,
        destinations: [ShareDestination] = [],
        defaultTemplateID: String? = nil,
        deliveryMode: AutoShareDeliveryMode = .queueOnly,
        lookbackWindowMinutes: Int = 180,
        imageFormat: AutoShareImageFormat = .square
    ) {
        self.isEnabled = isEnabled
        self.destinationsRaw = destinations.map { $0.rawValue }
        self.defaultTemplateID = defaultTemplateID
        self.deliveryModeRaw = deliveryMode.rawValue
        self.lookbackWindowMinutes = lookbackWindowMinutes
        self.imageFormatRaw = imageFormat.rawValue
        self.jobsData = nil
        self.lastModified = Date()
    }

    // MARK: - Default

    static func defaultConfig() -> AutoShareConfig {
        AutoShareConfig(isEnabled: false, destinations: [])
    }
}

enum AutoShareDeliveryMode: String, Codable, CaseIterable, Identifiable {
    case queueOnly = "queue_only"
    case shortcutMessage = "shortcut_message"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .queueOnly:
            return "Queue Only"
        case .shortcutMessage:
            return "Shortcuts Message"
        }
    }
}

enum AutoShareImageFormat: String, Codable, CaseIterable, Identifiable {
    case square = "square"
    case story = "story"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .square:
            return "Square"
        case .story:
            return "Story"
        }
    }

    var outputFormat: ImageOutputFormat {
        switch self {
        case .square:
            return .square
        case .story:
            return .story
        }
    }
}

/// Social media destinations for automatic sharing
enum ShareDestination: String, Codable, CaseIterable, Identifiable {
    case instagram = "instagram"
    case twitter = "twitter"
    case facebook = "facebook"
    case strava = "strava"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .twitter: return "X (Twitter)"
        case .facebook: return "Facebook"
        case .strava: return "Strava"
        }
    }

    var iconName: String {
        // Using generic icons since SF Symbols doesn't have brand logos
        switch self {
        case .instagram: return "camera"
        case .twitter: return "bubble.left"
        case .facebook: return "person.2"
        case .strava: return "figure.run"
        }
    }
}
