//
//  GenerateLatestWorkoutShareIntent.swift
//  ShareMyRun
//
//  Created by Codex on 2/22/26.
//

import AppIntents
import Foundation
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct GenerateLatestWorkoutShareIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate Latest Workout Share"
    static var description = IntentDescription(
        "Creates a share image for your most recently completed workout. Use this from a Shortcut automation and pass the image into Send Message."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Prefer Queued Image",
        description: "Use the latest prepared auto-share image if one is already queued."
    )
    var preferQueuedImage: Bool

    @Parameter(
        title: "Lookback Minutes",
        description: "Only consider workouts completed within this window."
    )
    var lookbackMinutes: Int

    init() {
        self.preferQueuedImage = true
        self.lookbackMinutes = 180
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        let modelContainer = try AppModelContainer.make(isStoredInMemoryOnly: false)
        let modelContext = ModelContext(modelContainer)
        let autoShareCoordinator = AutoShareCoordinator()
        let repository = WorkoutRepository()

        let workouts = try await repository.syncWorkouts(modelContext: modelContext)

        if preferQueuedImage {
            _ = try autoShareCoordinator.enqueueEligibleWorkouts(
                from: workouts,
                modelContext: modelContext
            )
            _ = await autoShareCoordinator.processPendingJobs(modelContext: modelContext)

            if let readyJob = try autoShareCoordinator.latestReadyJob(modelContext: modelContext),
               let imageData = readyJob.imageData {
                try autoShareCoordinator.markJobDelivered(readyJob, modelContext: modelContext)
                let file = IntentFile(data: imageData, filename: filename(for: readyJob.workoutEndDate), type: .png)
                return .result(
                    value: file,
                    dialog: "Generated your latest workout share image."
                )
            }
        }

        guard let workout = autoShareCoordinator.mostRecentWorkout(
            from: workouts,
            lookbackMinutes: lookbackMinutes
        ) else {
            throw AutoShareCoordinatorError.noRecentWorkout
        }

        let image = try await autoShareCoordinator.generateImageForWorkout(
            workout,
            modelContext: modelContext
        )

        guard let imageData = image.pngData() else {
            throw AutoShareCoordinatorError.imageEncodingFailed
        }

        let file = IntentFile(data: imageData, filename: filename(for: workout.endDate), type: .png)
        return .result(
            value: file,
            dialog: "Workout share image is ready."
        )
    }

    private func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm"
        return "sharemyrun-\(formatter.string(from: date)).png"
    }
}

struct ShareMyRunAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GenerateLatestWorkoutShareIntent(),
            phrases: [
                "Generate latest workout share with \(.applicationName)",
                "Create workout share image in \(.applicationName)",
            ],
            shortTitle: "Latest Workout Share",
            systemImageName: "figure.run"
        )
    }
}
