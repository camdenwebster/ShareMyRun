//
//  WorkoutListViewModelTests.swift
//  ShareMyRunTests
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import Testing
@testable import ShareMyRun

@Suite("WorkoutListViewModel Tests")
struct WorkoutListViewModelTests {

    // MARK: - Initial State Tests

    @Suite("Initial State")
    struct InitialStateTests {

        @Test("ViewModel initializes with empty state")
        func viewModelInitializesWithEmptyState() {
            let viewModel = WorkoutListViewModel(repository: MockWorkoutRepository())

            #expect(viewModel.workouts.isEmpty)
            #expect(viewModel.filteredWorkouts.isEmpty)
            #expect(viewModel.isLoading == false)
            #expect(viewModel.errorMessage == nil)
            #expect(viewModel.showError == false)
            #expect(viewModel.selectedFilter == .all)
        }
    }

    // MARK: - Filter Tests

    @Suite("Filtering")
    struct FilteringTests {

        @Test("All filters returns expected options")
        func allFiltersReturnsExpectedOptions() {
            let filters = WorkoutTypeFilter.allFilters

            // Should include 'all' plus all workout types
            #expect(filters.contains(.all))
            #expect(filters.contains(.type(.running)))
            #expect(filters.contains(.type(.cycling)))
            #expect(filters.contains(.type(.swimming)))
            #expect(filters.contains(.type(.hiking)))
            #expect(filters.contains(.type(.walking)))
            #expect(filters.contains(.type(.other)))
        }

        @Test("Filter has correct display names")
        func filterHasCorrectDisplayNames() {
            #expect(WorkoutTypeFilter.all.displayName == "All")
            #expect(WorkoutTypeFilter.type(.running).displayName == "Running")
            #expect(WorkoutTypeFilter.type(.cycling).displayName == "Cycling")
        }

        @Test("Filter has correct icon names")
        func filterHasCorrectIconNames() {
            #expect(WorkoutTypeFilter.all.iconName == "list.bullet")
            #expect(WorkoutTypeFilter.type(.running).iconName == "figure.run")
        }

        @Test("Filter equality works correctly")
        func filterEqualityWorksCorrectly() {
            #expect(WorkoutTypeFilter.all == WorkoutTypeFilter.all)
            #expect(WorkoutTypeFilter.type(.running) == WorkoutTypeFilter.type(.running))
            #expect(WorkoutTypeFilter.all != WorkoutTypeFilter.type(.running))
            #expect(WorkoutTypeFilter.type(.running) != WorkoutTypeFilter.type(.cycling))
        }
    }

    // MARK: - Error Handling Tests

    @Suite("Error Handling")
    struct ErrorHandlingTests {

        @Test("Clear error resets error state")
        func clearErrorResetsState() {
            let viewModel = WorkoutListViewModel(repository: MockWorkoutRepository())
            viewModel.showError = true

            viewModel.clearError()

            #expect(viewModel.showError == false)
            #expect(viewModel.errorMessage == nil)
        }
    }
}
