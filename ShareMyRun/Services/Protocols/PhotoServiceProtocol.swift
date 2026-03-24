//
//  PhotoServiceProtocol.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import Photos
import UIKit

/// Represents the authorization status for Photo Library access
enum PhotoLibraryAuthorizationStatus {
    case notDetermined
    case restricted
    case denied
    case authorized
    case limited
}

/// Protocol defining the interface for Photo Library operations
/// Enables dependency injection and testability
protocol PhotoServiceProtocol: Sendable {
    /// Requests authorization to read photos from the library
    /// - Returns: The resulting authorization status
    func requestReadAuthorization() async -> PhotoLibraryAuthorizationStatus

    /// Requests authorization to add photos to the library
    /// - Returns: The resulting authorization status
    func requestAddAuthorization() async -> PhotoLibraryAuthorizationStatus

    /// Fetches the most recent image from the camera roll
    /// - Returns: The most recent UIImage, or nil if unavailable
    func fetchMostRecentImage() async throws -> UIImage?

    /// Saves an image to the photo library
    /// - Parameter image: The image to save
    /// - Throws: PhotoServiceError if save fails
    func saveImage(_ image: UIImage) async throws
}

/// Errors that can occur during Photo Library operations
enum PhotoServiceError: Error, LocalizedError {
    case authorizationDenied
    case authorizationRestricted
    case fetchFailed(underlying: Error?)
    case saveFailed(underlying: Error?)
    case noPhotosAvailable
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Photo library access was denied. Please enable access in Settings."
        case .authorizationRestricted:
            return "Photo library access is restricted on this device."
        case .fetchFailed(let error):
            if let error = error {
                return "Failed to fetch photo: \(error.localizedDescription)"
            }
            return "Failed to fetch photo."
        case .saveFailed(let error):
            if let error = error {
                return "Failed to save photo: \(error.localizedDescription)"
            }
            return "Failed to save photo."
        case .noPhotosAvailable:
            return "No photos available in the library."
        case .invalidImageData:
            return "The image data is invalid."
        }
    }
}
