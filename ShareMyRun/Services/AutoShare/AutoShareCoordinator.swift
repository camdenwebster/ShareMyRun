//
//  AutoShareCoordinator.swift
//  ShareMyRun
//
//  Created by Codex on 2/22/26.
//

import Foundation
import SwiftData
import UIKit

protocol AutoShareImageGenerating: Sendable {
    func generateImage(
        for workout: Workout,
        configuration: ShareConfiguration,
        format: ImageOutputFormat,
        selectedPhoto: UIImage?
    ) async throws -> UIImage
}

extension ImageGenerator: AutoShareImageGenerating {}

enum AutoShareCoordinatorError: Error, LocalizedError {
    case noRecentWorkout
    case imageEncodingFailed
    case workoutNotFound

    var errorDescription: String? {
        switch self {
        case .noRecentWorkout:
            return "No recently completed workout is available to auto-share."
        case .imageEncodingFailed:
            return "Failed to encode the generated auto-share image."
        case .workoutNotFound:
            return "The workout for this auto-share job could not be found."
        }
    }
}

final class AutoShareCoordinator {
    private let imageGenerator: AutoShareImageGenerating
    private let now: () -> Date

    init(
        imageGenerator: AutoShareImageGenerating = ImageGenerator(),
        now: @escaping () -> Date = Date.init
    ) {
        self.imageGenerator = imageGenerator
        self.now = now
    }

    func queueAndProcessEligibleWorkouts(
        _ workouts: [Workout],
        modelContext: ModelContext
    ) async {
        do {
            let config = try loadOrCreateConfig(modelContext: modelContext)
            guard config.isEnabled else {
                return
            }

            let queuedCount = try enqueueEligibleWorkouts(
                from: workouts,
                modelContext: modelContext
            )

            guard queuedCount > 0 else {
                return
            }

            _ = await processPendingJobs(modelContext: modelContext)
        } catch {
            // Auto-share is best-effort and should not interrupt normal workout loading.
            print("AutoShareCoordinator queue/process error: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func enqueueEligibleWorkouts(
        from workouts: [Workout],
        modelContext: ModelContext,
        includeHistorical: Bool = false
    ) throws -> Int {
        guard !workouts.isEmpty else {
            return 0
        }

        let config = try loadOrCreateConfig(modelContext: modelContext)
        guard config.isEnabled else {
            return 0
        }

        let currentDate = now()
        let eligibleWorkouts = workouts
            .filter { workout in
                if includeHistorical {
                    return true
                }

                let cutoffDate = currentDate.addingTimeInterval(
                    -Double(max(config.lookbackWindowMinutes, 5) * 60)
                )
                return workout.endDate >= cutoffDate && workout.endDate <= currentDate.addingTimeInterval(300)
            }
            .sorted { $0.endDate > $1.endDate }

        guard !eligibleWorkouts.isEmpty else {
            return 0
        }

        var existingJobIDs = Set(config.jobs.map(\.workoutHealthKitID))
        var queuedJobs = config.jobs

        var queuedCount = 0
        for workout in eligibleWorkouts where !existingJobIDs.contains(workout.healthKitID) {
            let job = AutoShareJob(
                workoutHealthKitID: workout.healthKitID,
                workoutEndDate: workout.endDate,
                status: .pending,
                messageBody: Self.defaultMessage(for: workout)
            )
            queuedJobs.append(job)
            existingJobIDs.insert(workout.healthKitID)
            queuedCount += 1
        }

        guard queuedCount > 0 else {
            return 0
        }

        config.jobs = queuedJobs
        config.lastModified = currentDate
        try modelContext.save()
        return queuedCount
    }

    @discardableResult
    func processPendingJobs(modelContext: ModelContext) async -> Int {
        do {
            let config = try loadOrCreateConfig(modelContext: modelContext)
            guard config.isEnabled else {
                return 0
            }

            var jobs = config.jobs
            let pendingIndexes = jobs.indices
                .filter { jobs[$0].status == .pending }
                .sorted { jobs[$0].createdAt < jobs[$1].createdAt }
                .prefix(20)

            guard !pendingIndexes.isEmpty else {
                return 0
            }

            var processedCount = 0
            for index in pendingIndexes {
                var job = jobs[index]
                processedCount += 1
                do {
                    let workout = try fetchWorkout(
                        healthKitID: job.workoutHealthKitID,
                        modelContext: modelContext
                    )

                    guard let workout else {
                        throw AutoShareCoordinatorError.workoutNotFound
                    }

                    let image = try await generateImage(
                        for: workout,
                        autoShareConfig: config
                    )

                    guard let imageData = image.pngData() else {
                        throw AutoShareCoordinatorError.imageEncodingFailed
                    }

                    job.imageData = imageData
                    job.messageBody = Self.defaultMessage(for: workout)
                    job.failureReason = nil
                    job.status = .ready
                } catch {
                    job.status = .failed
                    job.failureReason = error.localizedDescription
                }

                job.attemptCount += 1
                job.lastAttemptAt = now()
                job.updatedAt = now()
                jobs[index] = job
            }

            config.jobs = jobs
            config.lastModified = now()
            try modelContext.save()
            return processedCount
        } catch {
            print("AutoShareCoordinator process error: \(error.localizedDescription)")
            return 0
        }
    }

    func latestReadyJob(modelContext: ModelContext) throws -> AutoShareJob? {
        let config = try loadOrCreateConfig(modelContext: modelContext)
        return config.jobs
            .filter { $0.status == .ready }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    func markJobDelivered(_ job: AutoShareJob, modelContext: ModelContext) throws {
        let config = try loadOrCreateConfig(modelContext: modelContext)
        var jobs = config.jobs

        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else {
            return
        }

        jobs[index].status = .delivered
        jobs[index].updatedAt = now()
        config.jobs = jobs
        config.lastModified = now()
        try modelContext.save()
    }

    func mostRecentWorkout(
        from workouts: [Workout],
        lookbackMinutes: Int
    ) -> Workout? {
        let cutoffDate = now().addingTimeInterval(-Double(max(lookbackMinutes, 5) * 60))
        return workouts
            .filter { $0.endDate >= cutoffDate }
            .sorted { $0.endDate > $1.endDate }
            .first
    }

    func generateImageForWorkout(
        _ workout: Workout,
        modelContext: ModelContext
    ) async throws -> UIImage {
        let config = try loadOrCreateConfig(modelContext: modelContext)
        return try await generateImage(for: workout, autoShareConfig: config)
    }

    func loadOrCreateConfig(modelContext: ModelContext) throws -> AutoShareConfig {
        var descriptor = FetchDescriptor<AutoShareConfig>()
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let newConfig = AutoShareConfig.defaultConfig()
        modelContext.insert(newConfig)
        try modelContext.save()
        return newConfig
    }

    private func fetchWorkout(
        healthKitID: String,
        modelContext: ModelContext
    ) throws -> Workout? {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.healthKitID == healthKitID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func generateImage(
        for workout: Workout,
        autoShareConfig: AutoShareConfig
    ) async throws -> UIImage {
        let shareConfiguration = resolvedShareConfiguration(for: workout)
        return try await imageGenerator.generateImage(
            for: workout,
            configuration: shareConfiguration,
            format: autoShareConfig.imageFormat.outputFormat,
            selectedPhoto: nil
        )
    }

    private func resolvedShareConfiguration(for workout: Workout) -> ShareConfiguration {
        let source = workout.shareConfiguration ?? ShareConfiguration.defaultConfiguration(for: workout)
        let selectedStatistics = source.selectedStatistics.isEmpty
            ? [StatisticType.distance, .duration, .pace]
            : source.selectedStatistics

        let backgroundType: BackgroundType
        if source.backgroundType == .selectedPhoto {
            backgroundType = workout.hasRoute ? .routeMap : .lastPhoto
        } else {
            backgroundType = source.backgroundType
        }

        let configuration = ShareConfiguration(
            workout: nil,
            selectedStatistics: selectedStatistics,
            backgroundType: backgroundType,
            font: source.font,
            fontSize: source.fontSize,
            textColor: source.textColor,
            textPosition: source.textPosition,
            routeRedactionDistance: source.routeRedactionDistance
        )

        configuration.featuredStatistic =
            selectedStatistics.contains(source.featuredStatistic)
            ? source.featuredStatistic
            : (selectedStatistics.first ?? .distance)

        return configuration
    }

    private static func defaultMessage(for workout: Workout) -> String {
        if let miles = workout.distanceInMiles {
            return "Finished a \(String(format: "%.2f", miles)) mi \(workout.type.displayName.lowercased()) workout."
        }

        return "Finished a \(workout.type.displayName.lowercased()) workout in \(workout.formattedDuration)."
    }
}
