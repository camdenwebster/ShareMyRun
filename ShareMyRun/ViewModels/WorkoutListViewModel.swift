//
//  WorkoutListViewModel.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import SwiftData
import Observation

/// View model for the workout list screen
/// Manages workout fetching, filtering, and state
@Observable
final class WorkoutListViewModel {
    // MARK: - Published State

    /// All workouts fetched from storage/HealthKit
    private(set) var workouts: [Workout] = []

    /// Whether workouts are currently being fetched
    private(set) var isLoading: Bool = false

    /// Current error message, if any
    private(set) var errorMessage: String?

    /// Whether the error alert should be shown
    var showError: Bool = false

    /// Whether HealthKit permission was explicitly denied
    private(set) var healthKitPermissionDenied: Bool = false

    /// The currently selected workout type filter
    var selectedFilter: WorkoutTypeFilter = .all {
        didSet {
            applyFilter()
        }
    }

    /// Workouts filtered by the selected type
    private(set) var filteredWorkouts: [Workout] = []

    // MARK: - Dependencies

    private let repository: WorkoutRepositoryProtocol
    private let autoShareCoordinator: AutoShareCoordinator
    private var modelContext: ModelContext?

    // MARK: - Initialization

    init(
        repository: WorkoutRepositoryProtocol = WorkoutRepository(),
        autoShareCoordinator: AutoShareCoordinator = AutoShareCoordinator()
    ) {
        self.repository = repository
        self.autoShareCoordinator = autoShareCoordinator
    }

    // MARK: - Public Methods

    /// Sets the model context for SwiftData operations
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    /// Fetches workouts from HealthKit and local storage
    /// Call on view appear and pull-to-refresh
    func fetchWorkouts() async {
        guard let modelContext = modelContext else {
            errorMessage = "Model context not available"
            showError = true
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Sync from HealthKit (will also fetch stored workouts)
            workouts = try await repository.syncWorkouts(modelContext: modelContext)
            applyFilter()
            await autoShareCoordinator.queueAndProcessEligibleWorkouts(
                workouts,
                modelContext: modelContext
            )
        } catch let error as HealthServiceError {
            handleHealthServiceError(error)
        } catch {
            errorMessage = "Failed to fetch workouts: \(error.localizedDescription)"
            showError = true
        }

        isLoading = false
    }

    /// Loads only locally stored workouts (no HealthKit sync)
    /// Useful for quick initial load
    func loadStoredWorkouts() {
        guard let modelContext = modelContext else {
            return
        }

        do {
            workouts = try repository.fetchStoredWorkouts(modelContext: modelContext)
            applyFilter()
        } catch {
            errorMessage = "Failed to load workouts: \(error.localizedDescription)"
            showError = true
        }
    }

    /// Clears the current error
    func clearError() {
        errorMessage = nil
        showError = false
    }

    // MARK: - Private Methods

    /// Applies the current filter to the workouts
    private func applyFilter() {
        switch selectedFilter {
        case .all:
            filteredWorkouts = workouts
        case .type(let workoutType):
            filteredWorkouts = workouts.filter { $0.type == workoutType }
        }
    }

    /// Handles HealthKit-specific errors with appropriate messaging
    private func handleHealthServiceError(_ error: HealthServiceError) {
        switch error {
        case .healthKitNotAvailable:
            errorMessage = "HealthKit is not available on this device."
            showError = true
        case .authorizationDenied:
            // Set flag for dedicated UI instead of alert
            healthKitPermissionDenied = true
        case .authorizationNotDetermined:
            errorMessage = "Health data access needs to be granted."
            showError = true
        case .fetchFailed(let underlying):
            errorMessage = "Failed to fetch workouts: \(underlying.localizedDescription)"
            showError = true
        case .noRouteData:
            // This isn't an error for the list view
            break
        }
    }

    /// Resets the permission denied state (call after user returns from Settings)
    func resetPermissionDeniedState() {
        healthKitPermissionDenied = false
    }
}

// MARK: - Workout Type Filter

/// Filter options for the workout list
enum WorkoutTypeFilter: Equatable, Identifiable {
    case all
    case type(WorkoutType)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .type(let workoutType):
            return workoutType.rawValue
        }
    }

    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .type(let workoutType):
            return workoutType.displayName
        }
    }

    var iconName: String {
        switch self {
        case .all:
            return "list.bullet"
        case .type(let workoutType):
            return workoutType.iconName
        }
    }

    /// All available filter options
    static var allFilters: [WorkoutTypeFilter] {
        [.all] + WorkoutType.allCases.filter { $0 != .other }.map { .type($0) } + [.type(.other)]
    }
}
