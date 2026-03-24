//
//  ImageGenerator.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import UIKit
import SwiftUI
import MapKit

/// Service for generating shareable workout images
/// Combines background (route map or photo) with statistics overlay
final class ImageGenerator {
    private let routeMapRenderer: RouteMapRenderer
    private let statisticsRenderer: StatisticsOverlayRenderer
    private let photoService: PhotoServiceProtocol

    init(
        routeMapRenderer: RouteMapRenderer = RouteMapRenderer(),
        statisticsRenderer: StatisticsOverlayRenderer = StatisticsOverlayRenderer(),
        photoService: PhotoServiceProtocol = PhotoService()
    ) {
        self.routeMapRenderer = routeMapRenderer
        self.statisticsRenderer = statisticsRenderer
        self.photoService = photoService
    }

    // MARK: - Generation

    /// Generates a shareable image for a workout
    /// - Parameters:
    ///   - workout: The workout to generate an image for
    ///   - configuration: The share configuration with styling options
    ///   - format: The output format (square or story)
    ///   - selectedPhoto: Optional selected photo for custom background
    /// - Returns: Generated image ready for sharing
    func generateImage(
        for workout: Workout,
        configuration: ShareConfiguration,
        format: ImageOutputFormat,
        selectedPhoto: UIImage? = nil
    ) async throws -> UIImage {
        // Get background image
        let backgroundImage = try await getBackgroundImage(
            for: workout,
            backgroundType: configuration.backgroundType,
            selectedPhoto: selectedPhoto,
            size: format.size
        )

        // Prepare statistics
        let allStatistics = prepareStatistics(workout: workout, selectedStats: configuration.selectedStatistics)
        let featuredStat = allStatistics.first { $0.0 == configuration.featuredStatistic }
        let sideStatistics = allStatistics.filter { $0.0 != configuration.featuredStatistic }

        // Create statistics configuration
        let statsConfig = StatisticsOverlayRenderer.Configuration(
            size: format.size,
            statistics: sideStatistics,
            featuredStatistic: featuredStat,
            fontName: configuration.font.fontName,
            fontSize: scaledFontSize(configuration.fontSize, for: format),
            textColor: UIColor(configuration.textColor),
            position: configuration.textPosition,
            addShadow: true,
            padding: scaledPadding(for: format)
        )

        // Render final image with overlay
        let finalImage = statisticsRenderer.render(onto: backgroundImage, configuration: statsConfig)

        guard !SharePrivacySettings.removeWatermark else {
            return finalImage
        }

        return addWatermark(
            to: finalImage,
            size: format.size,
            textPosition: configuration.textPosition
        )
    }

    // MARK: - Private Helpers

    /// Gets the background image based on the selected type
    private func getBackgroundImage(
        for workout: Workout,
        backgroundType: BackgroundType,
        selectedPhoto: UIImage?,
        size: CGSize
    ) async throws -> UIImage {
        switch backgroundType {
        case .routeMap:
            guard let coordinates = workout.routeCoordinates, coordinates.count >= 2 else {
                throw ImageGeneratorError.noRouteData
            }

            let mapConfig = RouteMapRenderer.Configuration(
                size: size,
                routeColor: .systemBlue,
                routeLineWidth: size.width / 270, // Scale line width to image size
                mapType: .standard,
                padding: UIEdgeInsets(top: 60, left: 60, bottom: 60, right: 60),
                showMarkers: true,
                redactionDistance: SharePrivacySettings.routeRedactionDistance.meters
            )

            return try await routeMapRenderer.render(coordinates: coordinates, configuration: mapConfig)

        case .lastPhoto:
            guard let photo = try await photoService.fetchMostRecentImage() else {
                throw ImageGeneratorError.noPhotoAvailable
            }
            return photo

        case .selectedPhoto:
            guard let photo = selectedPhoto else {
                throw ImageGeneratorError.noPhotoSelected
            }
            return photo
        }
    }

    /// Prepares statistics data for rendering
    private func prepareStatistics(
        workout: Workout,
        selectedStats: [StatisticType]
    ) -> [(StatisticType, String)] {
        selectedStats.compactMap { stat in
            let value = stat.getValue(from: workout)
            let formatted = stat.format(value: value, from: workout)

            // Skip N/A values
            if formatted == "N/A" {
                return nil
            }

            return (stat, formatted)
        }
    }

    /// Scales font size for the output format
    private func scaledFontSize(_ baseSize: CGFloat, for format: ImageOutputFormat) -> CGFloat {
        // Base size is designed for ~375pt screen width
        // Scale proportionally for 1080px output
        let scaleFactor = format.size.width / 375.0
        return baseSize * scaleFactor
    }

    /// Gets scaled padding for the output format
    private func scaledPadding(for format: ImageOutputFormat) -> CGFloat {
        let basePadding: CGFloat = 16
        let scaleFactor = format.size.width / 375.0
        return basePadding * scaleFactor
    }

    /// Adds a subtle watermark to the image
    private func addWatermark(
        to image: UIImage,
        size: CGSize,
        textPosition: TextPosition
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Draw original image
            image.draw(at: .zero)

            // Add watermark
            let watermarkText = "ShareMyRun"
            let fontSize = size.width / 40 // Subtle size
            let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white.withAlphaComponent(0.6)
            ]

            let attributedText = NSAttributedString(string: watermarkText, attributes: attributes)
            let textSize = attributedText.size()
            let padding = size.width / 30
            let x = size.width - textSize.width - padding
            let y: CGFloat

            switch textPosition.watermarkAlignment {
            case .topTrailing:
                y = padding
            case .bottomTrailing:
                y = size.height - textSize.height - padding
            default:
                y = size.height - textSize.height - padding
            }

            attributedText.draw(at: CGPoint(x: x, y: y))
        }
    }
}

// MARK: - Errors

enum ImageGeneratorError: Error, LocalizedError {
    case noRouteData
    case noPhotoAvailable
    case noPhotoSelected
    case renderingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noRouteData:
            return "This workout has no GPS route data."
        case .noPhotoAvailable:
            return "No photos available in the photo library."
        case .noPhotoSelected:
            return "Please select a photo to use as background."
        case .renderingFailed(let error):
            return "Failed to render image: \(error.localizedDescription)"
        }
    }
}
