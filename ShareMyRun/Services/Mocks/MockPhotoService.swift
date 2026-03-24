//
//  MockPhotoService.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import UIKit

/// Mock implementation of PhotoServiceProtocol for testing
final class MockPhotoService: PhotoServiceProtocol, @unchecked Sendable {

    // MARK: - Configuration

    /// The authorization status to return for read requests
    nonisolated(unsafe) var mockReadAuthorizationStatus: PhotoLibraryAuthorizationStatus = .authorized

    /// The authorization status to return for add requests
    nonisolated(unsafe) var mockAddAuthorizationStatus: PhotoLibraryAuthorizationStatus = .authorized

    /// The image to return from fetchMostRecentImage
    nonisolated(unsafe) var mockMostRecentImage: UIImage? = nil

    /// Whether fetch should throw an error
    nonisolated(unsafe) var shouldThrowOnFetch: Bool = false
    nonisolated(unsafe) var fetchError: Error = PhotoServiceError.fetchFailed(underlying: nil)

    /// Whether save should throw an error
    nonisolated(unsafe) var shouldThrowOnSave: Bool = false
    nonisolated(unsafe) var saveError: Error = PhotoServiceError.saveFailed(underlying: nil)

    // MARK: - Call Tracking

    /// Number of times requestReadAuthorization was called
    nonisolated(unsafe) private(set) var requestReadAuthorizationCallCount = 0

    /// Number of times requestAddAuthorization was called
    nonisolated(unsafe) private(set) var requestAddAuthorizationCallCount = 0

    /// Number of times fetchMostRecentImage was called
    nonisolated(unsafe) private(set) var fetchMostRecentImageCallCount = 0

    /// Number of times saveImage was called
    nonisolated(unsafe) private(set) var saveImageCallCount = 0

    /// The last image that was passed to saveImage
    nonisolated(unsafe) private(set) var lastSavedImage: UIImage? = nil

    // MARK: - PhotoServiceProtocol

    func requestReadAuthorization() async -> PhotoLibraryAuthorizationStatus {
        requestReadAuthorizationCallCount += 1
        return mockReadAuthorizationStatus
    }

    func requestAddAuthorization() async -> PhotoLibraryAuthorizationStatus {
        requestAddAuthorizationCallCount += 1
        return mockAddAuthorizationStatus
    }

    func fetchMostRecentImage() async throws -> UIImage? {
        fetchMostRecentImageCallCount += 1

        if shouldThrowOnFetch {
            throw fetchError
        }

        return mockMostRecentImage
    }

    func saveImage(_ image: UIImage) async throws {
        saveImageCallCount += 1
        lastSavedImage = image

        if shouldThrowOnSave {
            throw saveError
        }
    }

    // MARK: - Helpers

    /// Resets all call counts and tracking data
    func reset() {
        requestReadAuthorizationCallCount = 0
        requestAddAuthorizationCallCount = 0
        fetchMostRecentImageCallCount = 0
        saveImageCallCount = 0
        lastSavedImage = nil
    }
}
