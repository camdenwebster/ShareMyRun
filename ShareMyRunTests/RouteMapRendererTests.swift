//
//  RouteMapRendererTests.swift
//  ShareMyRunTests
//
//  Created by Codex on 3/24/26.
//

import CoreLocation
import Foundation
import Testing
@testable import ShareMyRun

@Suite("Route Map Renderer Tests")
struct RouteMapRendererTests {

    @Test("Privacy settings default route redaction to a quarter mile")
    func privacySettingsDefaultToQuarterMile() {
        let previousValue = UserDefaults.standard.object(forKey: SharePrivacySettings.routeRedactionDistanceKey)
        defer {
            if let previousValue {
                UserDefaults.standard.set(previousValue, forKey: SharePrivacySettings.routeRedactionDistanceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: SharePrivacySettings.routeRedactionDistanceKey)
            }
        }

        UserDefaults.standard.removeObject(forKey: SharePrivacySettings.routeRedactionDistanceKey)

        #expect(SharePrivacySettings.routeRedactionDistance == .quarterMile)
    }

    @Test("Route redaction trims both ends of the route")
    func routeRedactionTrimsBothEnds() {
        let coordinates = stride(from: 0.0, through: 1600.0, by: 100.0).map(makeCoordinate(northMeters:))

        let redacted = RouteMapRenderer.redactedCoordinates(
            from: coordinates,
            distance: RouteRedactionDistance.quarterMile.meters
        )

        #expect(redacted.count >= 2)

        let startDistance = distance(from: coordinates.first!, to: redacted.first!)
        let endDistance = distance(from: redacted.last!, to: coordinates.last!)
        let expectedDistance = RouteRedactionDistance.quarterMile.meters

        #expect(abs(startDistance - expectedDistance) < 15)
        #expect(abs(endDistance - expectedDistance) < 15)
    }

    private func makeCoordinate(northMeters: Double) -> RouteCoordinate {
        RouteCoordinate(
            latitude: 37.3349 + (northMeters / 111_111),
            longitude: -122.0090
        )
    }

    private func distance(from start: RouteCoordinate, to end: RouteCoordinate) -> CLLocationDistance {
        CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
    }
}
