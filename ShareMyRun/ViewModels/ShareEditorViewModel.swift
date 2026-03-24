//
//  ShareEditorViewModel.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import SwiftUI
import SwiftData
import Observation

/// View model for the share editor screen
/// Manages workout customization and image generation
@Observable
final class ShareEditorViewModel {
    // MARK: - Published State

    /// The workout being edited
    let workout: Workout

    /// The share configuration (persisted settings)
    private(set) var configuration: ShareConfiguration

    /// The most recently generated image used for sharing/export
    private(set) var generatedImage: UIImage?

    /// Whether an export image is currently being generated
    private(set) var isGeneratingImage: Bool = false

    /// Whether the share sheet should be shown
    var showShareSheet: Bool = false

    /// Whether the save confirmation should be shown
    var showSaveConfirmation: Bool = false

    /// Current error message, if any
    private(set) var errorMessage: String?
    var showError: Bool = false

    /// Current output format selection
    var outputFormat: ImageOutputFormat = .square

    /// Selected photo for custom background
    var selectedPhoto: UIImage?

    /// Most recent photo used for "Last Photo" preview background
    var lastPhotoPreview: UIImage?

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private let photoService: PhotoServiceProtocol
    private let imageGenerator: ImageGenerator

    // MARK: - Initialization

    init(
        workout: Workout,
        configuration: ShareConfiguration? = nil,
        photoService: PhotoServiceProtocol = PhotoService(),
        imageGenerator: ImageGenerator = ImageGenerator()
    ) {
        self.workout = workout
        self.configuration = configuration ?? ShareConfiguration.defaultConfiguration(for: workout)
        self.photoService = photoService
        self.imageGenerator = imageGenerator

        if !self.configuration.selectedStatistics.contains(self.configuration.featuredStatistic) {
            self.configuration.featuredStatistic = self.configuration.selectedStatistics.first ?? .distance
        }
    }

    // MARK: - Configuration

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context

        // Link configuration to workout if not already linked
        if configuration.workout == nil {
            configuration.workout = workout
            workout.shareConfiguration = configuration
            context.insert(configuration)
        }
    }

    // MARK: - Statistics Selection

    /// Available statistics for this workout
    var availableStatistics: [StatisticType] {
        StatisticType.allCases.filter { $0.isAvailable(for: workout) }
    }

    /// Toggles a statistic's selection
    func toggleStatistic(_ stat: StatisticType) {
        var current = configuration.selectedStatistics

        if current.contains(stat) {
            current.removeAll { $0 == stat }
        } else if current.count < 6 {
            // Maximum 6 stats allowed
            current.append(stat)
        }

        configuration.selectedStatistics = current

        if !current.contains(configuration.featuredStatistic) {
            configuration.featuredStatistic = current.first ?? .distance
        }

        saveConfiguration()
    }

    /// Sets a statistic as the featured statistic.
    /// If it isn't selected yet, it will be selected when possible.
    func setFeaturedStatistic(_ stat: StatisticType) {
        var selected = configuration.selectedStatistics

        if !selected.contains(stat) {
            guard selected.count < 6 else { return }
            selected.append(stat)
            configuration.selectedStatistics = selected
        }

        configuration.featuredStatistic = stat
        saveConfiguration()
    }

    func isFeaturedStatistic(_ stat: StatisticType) -> Bool {
        configuration.featuredStatistic == stat
    }

    /// Whether a statistic is currently selected
    func isStatisticSelected(_ stat: StatisticType) -> Bool {
        configuration.selectedStatistics.contains(stat)
    }

    /// Whether we can add more statistics (max 6)
    var canAddMoreStatistics: Bool {
        configuration.selectedStatistics.count < 6
    }

    // MARK: - Background Selection

    /// Sets the background type
    func setBackgroundType(_ type: BackgroundType) {
        configuration.backgroundType = type
        saveConfiguration()
    }

    /// Whether the route map option is available
    var isRouteMapAvailable: Bool {
        workout.hasRoute
    }

    /// Loads the most recent photo for "Last Photo" background
    func loadLastPhoto() async {
        guard configuration.backgroundType == .lastPhoto else { return }

        do {
            let status = await photoService.requestReadAuthorization()
            guard status == .authorized || status == .limited else {
                errorMessage = "Photo library access denied"
                showError = true
                return
            }

            lastPhotoPreview = try await photoService.fetchMostRecentImage()

            if lastPhotoPreview == nil {
                errorMessage = "No photos available in your library"
                showError = true
            }
        } catch {
            errorMessage = "Failed to load last photo: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Text Styling

    /// Sets the font
    func setFont(_ font: OverlayFont) {
        configuration.font = font
        saveConfiguration()
    }

    /// Sets the font size
    func setFontSize(_ size: CGFloat) {
        configuration.fontSize = max(12, min(32, size))
        saveConfiguration()
    }

    /// Sets the text color
    func setTextColor(_ color: Color) {
        configuration.textColor = color
        saveConfiguration()
    }

    /// Sets the text position
    func setTextPosition(_ position: TextPosition) {
        configuration.textPosition = position
        saveConfiguration()
    }

    // MARK: - Image Generation

    /// Generates the final image for sharing
    func generateFinalImage() async -> UIImage? {
        isGeneratingImage = true
        defer { isGeneratingImage = false }

        do {
            return try await imageGenerator.generateImage(
                for: workout,
                configuration: configuration,
                format: outputFormat,
                selectedPhoto: selectedPhoto
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }

    // MARK: - Sharing

    /// Shares the generated image
    func share() async {
        guard let image = await generateFinalImage() else {
            errorMessage = "Failed to generate image"
            showError = true
            return
        }

        // The actual sharing will be done by the view using UIActivityViewController
        generatedImage = image
        showShareSheet = true
    }

    /// Saves the image to the photo library
    func saveToPhotos() async {
        guard let image = await generateFinalImage() else {
            errorMessage = "Failed to generate image"
            showError = true
            return
        }

        do {
            let status = await photoService.requestAddAuthorization()
            guard status == .authorized else {
                errorMessage = "Photo library access denied"
                showError = true
                return
            }

            try await photoService.saveImage(image)
            showSaveConfirmation = true
        } catch {
            errorMessage = "Failed to save image: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Persistence

    /// Saves the current configuration to SwiftData
    private func saveConfiguration() {
        configuration.lastModified = Date()

        do {
            try modelContext?.save()
        } catch {
            print("Failed to save configuration: \(error)")
        }
    }

    /// Clears the current error
    func clearError() {
        errorMessage = nil
        showError = false
    }
}
