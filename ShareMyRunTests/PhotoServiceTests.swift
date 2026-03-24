//
//  PhotoServiceTests.swift
//  ShareMyRunTests
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import Testing
import UIKit
@testable import ShareMyRun

@Suite("PhotoService Tests")
struct PhotoServiceTests {

    // MARK: - Authorization Tests

    @Suite("Authorization")
    struct AuthorizationTests {

        @Test("Request read authorization returns authorized status")
        func requestReadAuthorizationAuthorized() async {
            let mockService = MockPhotoService()
            mockService.mockReadAuthorizationStatus = .authorized

            let status = await mockService.requestReadAuthorization()

            #expect(status == .authorized)
            #expect(mockService.requestReadAuthorizationCallCount == 1)
        }

        @Test("Request read authorization returns denied status")
        func requestReadAuthorizationDenied() async {
            let mockService = MockPhotoService()
            mockService.mockReadAuthorizationStatus = .denied

            let status = await mockService.requestReadAuthorization()

            #expect(status == .denied)
        }

        @Test("Request read authorization returns limited status")
        func requestReadAuthorizationLimited() async {
            let mockService = MockPhotoService()
            mockService.mockReadAuthorizationStatus = .limited

            let status = await mockService.requestReadAuthorization()

            #expect(status == .limited)
        }

        @Test("Request add authorization returns authorized status")
        func requestAddAuthorizationAuthorized() async {
            let mockService = MockPhotoService()
            mockService.mockAddAuthorizationStatus = .authorized

            let status = await mockService.requestAddAuthorization()

            #expect(status == .authorized)
            #expect(mockService.requestAddAuthorizationCallCount == 1)
        }

        @Test("Request add authorization returns denied status")
        func requestAddAuthorizationDenied() async {
            let mockService = MockPhotoService()
            mockService.mockAddAuthorizationStatus = .denied

            let status = await mockService.requestAddAuthorization()

            #expect(status == .denied)
        }
    }

    // MARK: - Fetch Image Tests

    @Suite("Fetch Image")
    struct FetchImageTests {

        @Test("Fetch most recent image returns configured image")
        func fetchMostRecentImageReturnsImage() async throws {
            let mockService = MockPhotoService()
            let testImage = UIImage()
            mockService.mockMostRecentImage = testImage

            let result = try await mockService.fetchMostRecentImage()

            #expect(result != nil)
            #expect(mockService.fetchMostRecentImageCallCount == 1)
        }

        @Test("Fetch most recent image returns nil when no image")
        func fetchMostRecentImageReturnsNil() async throws {
            let mockService = MockPhotoService()
            mockService.mockMostRecentImage = nil

            let result = try await mockService.fetchMostRecentImage()

            #expect(result == nil)
        }

        @Test("Fetch most recent image throws when configured")
        func fetchMostRecentImageThrows() async {
            let mockService = MockPhotoService()
            mockService.shouldThrowOnFetch = true
            mockService.fetchError = PhotoServiceError.authorizationDenied

            await #expect(throws: PhotoServiceError.self) {
                _ = try await mockService.fetchMostRecentImage()
            }
        }
    }

    // MARK: - Save Image Tests

    @Suite("Save Image")
    struct SaveImageTests {

        @Test("Save image succeeds and tracks the image")
        func saveImageSucceeds() async throws {
            let mockService = MockPhotoService()
            let testImage = UIImage()

            try await mockService.saveImage(testImage)

            #expect(mockService.saveImageCallCount == 1)
            #expect(mockService.lastSavedImage != nil)
        }

        @Test("Save image throws when configured")
        func saveImageThrows() async {
            let mockService = MockPhotoService()
            mockService.shouldThrowOnSave = true
            mockService.saveError = PhotoServiceError.authorizationDenied

            await #expect(throws: PhotoServiceError.self) {
                try await mockService.saveImage(UIImage())
            }
        }
    }

    // MARK: - Error Tests

    @Suite("Error Handling")
    struct ErrorTests {

        @Test("PhotoServiceError has proper descriptions")
        func errorDescriptions() {
            let denied = PhotoServiceError.authorizationDenied
            #expect(denied.errorDescription?.contains("denied") == true)

            let restricted = PhotoServiceError.authorizationRestricted
            #expect(restricted.errorDescription?.contains("restricted") == true)

            let noPhotos = PhotoServiceError.noPhotosAvailable
            #expect(noPhotos.errorDescription?.contains("No photos") == true)

            let invalidData = PhotoServiceError.invalidImageData
            #expect(invalidData.errorDescription?.contains("invalid") == true)

            let fetchFailed = PhotoServiceError.fetchFailed(underlying: nil)
            #expect(fetchFailed.errorDescription?.contains("fetch") == true)

            let saveFailed = PhotoServiceError.saveFailed(underlying: nil)
            #expect(saveFailed.errorDescription?.contains("save") == true)
        }
    }

    // MARK: - Reset Tests

    @Suite("Mock Reset")
    struct MockResetTests {

        @Test("Reset clears all call counts")
        func resetClearsCallCounts() async throws {
            let mockService = MockPhotoService()

            // Make some calls
            _ = await mockService.requestReadAuthorization()
            _ = await mockService.requestAddAuthorization()
            _ = try await mockService.fetchMostRecentImage()
            try await mockService.saveImage(UIImage())

            #expect(mockService.requestReadAuthorizationCallCount == 1)
            #expect(mockService.requestAddAuthorizationCallCount == 1)
            #expect(mockService.fetchMostRecentImageCallCount == 1)
            #expect(mockService.saveImageCallCount == 1)
            #expect(mockService.lastSavedImage != nil)

            // Reset
            mockService.reset()

            #expect(mockService.requestReadAuthorizationCallCount == 0)
            #expect(mockService.requestAddAuthorizationCallCount == 0)
            #expect(mockService.fetchMostRecentImageCallCount == 0)
            #expect(mockService.saveImageCallCount == 0)
            #expect(mockService.lastSavedImage == nil)
        }
    }
}
