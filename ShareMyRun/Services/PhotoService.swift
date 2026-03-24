//
//  PhotoService.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import Photos
import UIKit

/// Production implementation of PhotoServiceProtocol using PHPhotoLibrary
final class PhotoService: PhotoServiceProtocol, @unchecked Sendable {
    private let imageManager: PHImageManager

    init(imageManager: PHImageManager = PHImageManager.default()) {
        self.imageManager = imageManager
    }

    func requestReadAuthorization() async -> PhotoLibraryAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return mapAuthorizationStatus(status)
    }

    func requestAddAuthorization() async -> PhotoLibraryAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return mapAuthorizationStatus(status)
    }

    func fetchMostRecentImage() async throws -> UIImage? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw PhotoServiceError.authorizationDenied
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        guard let asset = fetchResult.firstObject else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            let targetSize = CGSize(width: 1080, height: 1920) // Story size

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: PhotoServiceError.fetchFailed(underlying: error))
                    return
                }

                // Check if this is the final result (not a degraded preview)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    func saveImage(_ image: UIImage) async throws {
        let addStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let readWriteStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        guard addStatus == .authorized || readWriteStatus == .authorized || readWriteStatus == .limited else {
            throw PhotoServiceError.authorizationDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoServiceError.saveFailed(underlying: error))
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func mapAuthorizationStatus(_ status: PHAuthorizationStatus) -> PhotoLibraryAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        @unknown default:
            return .notDetermined
        }
    }
}
