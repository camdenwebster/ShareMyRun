//
//  AutoShareCoordinatorTests.swift
//  ShareMyRunTests
//
//  Created by Codex on 2/22/26.
//

import Foundation
import SwiftData
import Testing
import UIKit
@testable import ShareMyRun

@Suite("AutoShareCoordinator Tests")
@MainActor
struct AutoShareCoordinatorTests {

    @Test("Enqueue returns zero when auto-share is disabled")
    func enqueueReturnsZeroWhenDisabled() throws {
        let container = try AppModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let fixedNow = Date()
        let coordinator = AutoShareCoordinator(
            imageGenerator: MockAutoShareImageGenerator(),
            now: { fixedNow }
        )

        let workout = makeWorkout(
            id: "disabled-1",
            endDate: fixedNow.addingTimeInterval(-300)
        )

        let queued = try coordinator.enqueueEligibleWorkouts(
            from: [workout],
            modelContext: context
        )
        let config = try coordinator.loadOrCreateConfig(modelContext: context)

        #expect(queued == 0)
        #expect(config.jobs.isEmpty)
    }

    @Test("Enqueue inserts one job and skips duplicates")
    func enqueueSkipsDuplicates() throws {
        let container = try AppModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let fixedNow = Date()
        let coordinator = AutoShareCoordinator(
            imageGenerator: MockAutoShareImageGenerator(),
            now: { fixedNow }
        )

        let config = try coordinator.loadOrCreateConfig(modelContext: context)
        config.isEnabled = true
        config.lookbackWindowMinutes = 180

        let workout = makeWorkout(
            id: "dedupe-1",
            endDate: fixedNow.addingTimeInterval(-120)
        )
        context.insert(workout)
        try context.save()

        let firstQueueCount = try coordinator.enqueueEligibleWorkouts(
            from: [workout],
            modelContext: context
        )
        let secondQueueCount = try coordinator.enqueueEligibleWorkouts(
            from: [workout],
            modelContext: context
        )

        #expect(firstQueueCount == 1)
        #expect(secondQueueCount == 0)
        #expect(try coordinator.loadOrCreateConfig(modelContext: context).jobs.count == 1)
    }

    @Test("Process pending jobs marks successful generations as ready")
    func processPendingMarksReady() async throws {
        let container = try AppModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let fixedNow = Date()
        let coordinator = AutoShareCoordinator(
            imageGenerator: MockAutoShareImageGenerator(),
            now: { fixedNow }
        )

        let config = try coordinator.loadOrCreateConfig(modelContext: context)
        config.isEnabled = true

        let workout = makeWorkout(
            id: "process-ready-1",
            endDate: fixedNow.addingTimeInterval(-60)
        )
        context.insert(workout)

        let job = AutoShareJob(
            workoutHealthKitID: workout.healthKitID,
            workoutEndDate: workout.endDate,
            status: .pending
        )
        config.jobs = [job]
        try context.save()

        let processed = await coordinator.processPendingJobs(modelContext: context)
        let storedJob = try coordinator.loadOrCreateConfig(modelContext: context)
            .jobs
            .first(where: { $0.workoutHealthKitID == workout.healthKitID })

        #expect(processed == 1)
        #expect(storedJob?.status == .ready)
        #expect(storedJob?.imageData != nil)
        #expect((storedJob?.attemptCount ?? 0) == 1)
    }

    @Test("Process pending jobs marks failures when generation throws")
    func processPendingMarksFailed() async throws {
        let container = try AppModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let fixedNow = Date()
        let coordinator = AutoShareCoordinator(
            imageGenerator: MockAutoShareImageGenerator(shouldThrow: true),
            now: { fixedNow }
        )

        let config = try coordinator.loadOrCreateConfig(modelContext: context)
        config.isEnabled = true

        let workout = makeWorkout(
            id: "process-fail-1",
            endDate: fixedNow.addingTimeInterval(-60)
        )
        context.insert(workout)

        let job = AutoShareJob(
            workoutHealthKitID: workout.healthKitID,
            workoutEndDate: workout.endDate,
            status: .pending
        )
        config.jobs = [job]
        try context.save()

        _ = await coordinator.processPendingJobs(modelContext: context)
        let storedJob = try coordinator.loadOrCreateConfig(modelContext: context)
            .jobs
            .first(where: { $0.workoutHealthKitID == workout.healthKitID })

        #expect(storedJob?.status == .failed)
        #expect((storedJob?.failureReason?.isEmpty == false))
        #expect((storedJob?.attemptCount ?? 0) == 1)
    }

    private func makeWorkout(id: String, endDate: Date) -> Workout {
        Workout(
            healthKitID: id,
            type: .running,
            startDate: endDate.addingTimeInterval(-3600),
            endDate: endDate,
            distance: 5000,
            duration: 3600,
            routeCoordinates: [
                RouteCoordinate(latitude: 37.3317, longitude: -122.0301),
                RouteCoordinate(latitude: 37.3320, longitude: -122.0290),
            ],
            calories: 300,
            averageHeartRate: 150,
            maxHeartRate: 168,
            averagePace: 0.72,
            elevationGain: 40
        )
    }
}

private struct MockAutoShareImageGenerator: AutoShareImageGenerating {
    var shouldThrow: Bool = false

    func generateImage(
        for workout: Workout,
        configuration: ShareConfiguration,
        format: ImageOutputFormat,
        selectedPhoto: UIImage?
    ) async throws -> UIImage {
        if shouldThrow {
            throw MockAutoShareImageGeneratorError.generationFailed
        }

        let renderer = UIGraphicsImageRenderer(size: format.size)
        return renderer.image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(origin: .zero, size: format.size))
        }
    }
}

private enum MockAutoShareImageGeneratorError: LocalizedError {
    case generationFailed

    var errorDescription: String? {
        "Mock image generation failed."
    }
}
