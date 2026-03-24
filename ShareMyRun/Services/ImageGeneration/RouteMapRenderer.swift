//
//  RouteMapRenderer.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import MapKit
import UIKit
import CoreLocation

/// Renders a workout route as a styled map image
final class RouteMapRenderer {

    /// Configuration for map rendering
    struct Configuration {
        /// Size of the output image
        let size: CGSize

        /// Color of the route line
        let routeColor: UIColor

        /// Width of the route line
        let routeLineWidth: CGFloat

        /// Map type (standard, satellite, hybrid)
        let mapType: MKMapType

        /// Padding around the route in points
        let padding: UIEdgeInsets

        /// Whether to show start/end markers
        let showMarkers: Bool

        /// Distance to trim from both ends of the route
        let redactionDistance: CLLocationDistance

        nonisolated static let `default` = Configuration(
            size: CGSize(width: 1080, height: 1080),
            routeColor: .systemBlue,
            routeLineWidth: 4,
            mapType: .standard,
            padding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
            showMarkers: true,
            redactionDistance: RouteRedactionDistance.quarterMile.meters
        )

        nonisolated static func forFormat(_ format: ImageOutputFormat) -> Configuration {
            Configuration(
                size: format.size,
                routeColor: .systemBlue,
                routeLineWidth: 4,
                mapType: .standard,
                padding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
                showMarkers: true,
                redactionDistance: RouteRedactionDistance.quarterMile.meters
            )
        }
    }

    // MARK: - Rendering

    /// Renders a route to a UIImage
    /// - Parameters:
    ///   - coordinates: Array of route coordinates
    ///   - configuration: Rendering configuration
    /// - Returns: Rendered map image
    func render(
        coordinates: [RouteCoordinate],
        configuration: Configuration = .default
    ) async throws -> UIImage {
        guard coordinates.count >= 2 else {
            throw RouteMapRendererError.insufficientCoordinates
        }

        let clCoordinates = Self.redactedCoordinates(
            from: coordinates.map(\.coordinate),
            distance: configuration.redactionDistance
        )

        guard clCoordinates.count >= 2 else {
            throw RouteMapRendererError.insufficientCoordinates
        }

        // Calculate the region that fits all coordinates
        let region = calculateRegion(for: clCoordinates, padding: configuration.padding, size: configuration.size)

        // Create map snapshotter options
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = configuration.size
        options.mapType = configuration.mapType
        options.showsBuildings = false

        // Create and start the snapshotter
        let snapshotter = MKMapSnapshotter(options: options)

        let snapshot = try await snapshotter.start()

        // Draw the route on the snapshot
        let image = drawRoute(
            on: snapshot,
            coordinates: clCoordinates,
            configuration: configuration
        )

        return image
    }

    // MARK: - Private Helpers

    static func redactedCoordinates(
        from coordinates: [RouteCoordinate],
        distance: CLLocationDistance
    ) -> [RouteCoordinate] {
        redactedCoordinates(from: coordinates.map(\.coordinate), distance: distance).map {
            RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    static func redactedCoordinates(
        from coordinates: [CLLocationCoordinate2D],
        distance: CLLocationDistance
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2, distance > 0 else { return coordinates }

        let totalDistance = routeDistance(for: coordinates)
        let minimumVisibleDistance: CLLocationDistance = 1
        let maximumTrim = max(0, (totalDistance - minimumVisibleDistance) / 2)
        let effectiveTrim = min(distance, maximumTrim)

        guard effectiveTrim > 0 else { return coordinates }

        let startTrimmed = trimStart(of: coordinates, by: effectiveTrim)
        let fullyTrimmed = trimEnd(of: startTrimmed, by: effectiveTrim)

        return fullyTrimmed.count >= 2 ? fullyTrimmed : coordinates
    }

    /// Calculates the map region to fit all coordinates
    private func calculateRegion(
        for coordinates: [CLLocationCoordinate2D],
        padding: UIEdgeInsets,
        size: CGSize
    ) -> MKCoordinateRegion {
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // Add padding percentage
        let latDelta = (maxLat - minLat) * 1.3
        let lonDelta = (maxLon - minLon) * 1.3

        // Ensure minimum span
        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.005),
            longitudeDelta: max(lonDelta, 0.005)
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    /// Draws the route polyline on the map snapshot
    private func drawRoute(
        on snapshot: MKMapSnapshotter.Snapshot,
        coordinates: [CLLocationCoordinate2D],
        configuration: Configuration
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: configuration.size)

        return renderer.image { context in
            // Draw the map image
            snapshot.image.draw(at: .zero)

            // Create the route path
            let path = UIBezierPath()

            for (index, coordinate) in coordinates.enumerated() {
                let point = snapshot.point(for: coordinate)

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            // Draw the route
            context.cgContext.setStrokeColor(configuration.routeColor.cgColor)
            context.cgContext.setLineWidth(configuration.routeLineWidth)
            context.cgContext.setLineCap(.round)
            context.cgContext.setLineJoin(.round)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.strokePath()

            // Draw markers if enabled
            if configuration.showMarkers, let first = coordinates.first, let last = coordinates.last {
                drawMarker(at: snapshot.point(for: first), color: .systemGreen, context: context)
                drawMarker(at: snapshot.point(for: last), color: .systemRed, context: context)
            }
        }
    }

    /// Draws a circular marker at a point
    private func drawMarker(at point: CGPoint, color: UIColor, context: UIGraphicsImageRendererContext) {
        let markerSize: CGFloat = 16
        let rect = CGRect(
            x: point.x - markerSize / 2,
            y: point.y - markerSize / 2,
            width: markerSize,
            height: markerSize
        )

        // White border
        context.cgContext.setFillColor(UIColor.white.cgColor)
        context.cgContext.fillEllipse(in: rect.insetBy(dx: -2, dy: -2))

        // Colored fill
        context.cgContext.setFillColor(color.cgColor)
        context.cgContext.fillEllipse(in: rect)
    }

    private static func routeDistance(for coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance {
        zip(coordinates, coordinates.dropFirst()).reduce(0) { partialResult, pair in
            partialResult + locationDistance(from: pair.0, to: pair.1)
        }
    }

    private static func trimEnd(
        of coordinates: [CLLocationCoordinate2D],
        by distance: CLLocationDistance
    ) -> [CLLocationCoordinate2D] {
        Array(trimStart(of: Array(coordinates.reversed()), by: distance).reversed())
    }

    private static func trimStart(
        of coordinates: [CLLocationCoordinate2D],
        by distance: CLLocationDistance
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2, distance > 0 else { return coordinates }

        var remainingDistance = distance

        for index in 1..<coordinates.count {
            let start = coordinates[index - 1]
            let end = coordinates[index]
            let segmentDistance = locationDistance(from: start, to: end)

            guard segmentDistance > 0 else { continue }

            if remainingDistance < segmentDistance {
                let fraction = remainingDistance / segmentDistance
                let trimmedStart = interpolatedCoordinate(from: start, to: end, fraction: fraction)
                return [trimmedStart] + Array(coordinates[index...])
            } else if remainingDistance == segmentDistance {
                return Array(coordinates[index...])
            } else {
                remainingDistance -= segmentDistance
            }
        }

        return coordinates
    }

    private static func interpolatedCoordinate(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        fraction: Double
    ) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: start.latitude + ((end.latitude - start.latitude) * fraction),
            longitude: start.longitude + ((end.longitude - start.longitude) * fraction)
        )
    }

    private static func locationDistance(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
    }
}

// MARK: - Errors

enum RouteMapRendererError: Error, LocalizedError {
    case insufficientCoordinates
    case snapshotFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .insufficientCoordinates:
            return "At least 2 coordinates are required to render a route."
        case .snapshotFailed(let error):
            return "Failed to create map snapshot: \(error.localizedDescription)"
        }
    }
}
