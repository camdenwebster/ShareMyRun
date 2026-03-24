//
//  WorkoutListView.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import SwiftUI
import SwiftData

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = WorkoutListViewModel()
    @State private var workoutScrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showsFilterChips {
                    FilterChipsView(selectedFilter: $viewModel.selectedFilter)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .opacity(chipVisibility)
                        .frame(height: 54 * chipVisibility)
                        .clipped()
                        .allowsHitTesting(chipVisibility > 0.2)
                        .animation(.easeInOut(duration: 0.2), value: chipVisibility)
                }

                Group {
                    if viewModel.isLoading && viewModel.workouts.isEmpty {
                        LoadingView()
                    } else if viewModel.healthKitPermissionDenied {
                        HealthKitDeniedView()
                    } else if viewModel.filteredWorkouts.isEmpty {
                        EmptyStateView(filter: viewModel.selectedFilter)
                    } else {
                        WorkoutList(
                            workouts: viewModel.filteredWorkouts,
                            scrollOffset: $workoutScrollOffset
                        )
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .refreshable {
                await viewModel.fetchWorkouts()
            }
            .task {
                viewModel.setModelContext(modelContext)
                viewModel.loadStoredWorkouts()
                await viewModel.fetchWorkouts()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.clearError()
                }
                if viewModel.errorMessage?.contains("Settings") == true {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && viewModel.healthKitPermissionDenied {
                    viewModel.resetPermissionDeniedState()
                    Task {
                        await viewModel.fetchWorkouts()
                    }
                }
            }
            .onChange(of: viewModel.filteredWorkouts.isEmpty) { _, isEmpty in
                if isEmpty {
                    workoutScrollOffset = 0
                }
            }
        }
    }

    private var showsFilterChips: Bool {
        !viewModel.healthKitPermissionDenied && !(viewModel.isLoading && viewModel.workouts.isEmpty)
    }

    private var chipVisibility: CGFloat {
        let progress = min(max((-workoutScrollOffset - 6) / 56, 0), 1)
        return 1 - progress
    }
}

// MARK: - Filter Chips View

private struct FilterChipsView: View {
    @Binding var selectedFilter: WorkoutTypeFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WorkoutTypeFilter.allFilters) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let filter: WorkoutTypeFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: filter.iconName)
                    .font(.caption)
                Text(filter.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(filter.displayName) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Workout List

private struct WorkoutList: View {
    let workouts: [Workout]
    @Binding var scrollOffset: CGFloat

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                ScrollOffsetReader()

                ForEach(monthSections) { section in
                    Section {
                        VStack(spacing: 10) {
                            ForEach(section.workouts, id: \.healthKitID) { workout in
                                NavigationLink {
                                    ShareEditorView(workout: workout)
                                } label: {
                                    WorkoutRow(workout: workout)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    } header: {
                        MonthHeaderView(monthStart: section.monthStart)
                    }
                }

                Color.clear
                    .frame(height: 12)
            }
            .padding(.top, 4)
        }
        .coordinateSpace(name: "WorkoutListScroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
    }

    private var monthSections: [WorkoutMonthSection] {
        let grouped = Dictionary(grouping: workouts) { workout in
            Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: workout.startDate)) ?? workout.startDate
        }

        return grouped
            .map { monthStart, monthWorkouts in
                WorkoutMonthSection(
                    monthStart: monthStart,
                    workouts: monthWorkouts.sorted { $0.startDate > $1.startDate }
                )
            }
            .sorted { $0.monthStart > $1.monthStart }
    }
}

private struct ScrollOffsetReader: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("WorkoutListScroll")).minY
                )
        }
        .frame(height: 0)
    }
}

private struct MonthHeaderView: View {
    let monthStart: Date

    var body: some View {
        Text(monthStart.formatted(.dateTime.month(.wide).year()))
            .font(.title3)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
    }
}

private struct WorkoutMonthSection: Identifiable {
    let monthStart: Date
    let workouts: [Workout]

    var id: String {
        let components = Calendar.current.dateComponents([.year, .month], from: monthStart)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Workout Row

private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.type.iconName)
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 42, height: 42)
                .background(Color.green.opacity(0.16))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.type.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let miles = workout.distanceInMiles {
                    Text(String(format: "%.2fMI", miles))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                } else {
                    Text(workout.formattedDuration)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
            }

            Spacer(minLength: 8)

            Text(relativeDateLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(workout.type.displayName) on \(workout.startDate.formatted(date: .abbreviated, time: .omitted))")
        .accessibilityValue(workout.distanceInMiles.map { String(format: "%.2f miles, %@", $0, workout.formattedDuration) } ?? workout.formattedDuration)
    }

    private var relativeDateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(workout.startDate) {
            return "Today"
        }
        if calendar.isDateInYesterday(workout.startDate) {
            return "Yesterday"
        }

        if let days = calendar.dateComponents([.day], from: workout.startDate, to: Date()).day,
           days >= 0,
           days < 7 {
            return workout.startDate.formatted(.dateTime.weekday(.wide))
        }

        return workout.startDate.formatted(.dateTime.month().day().year(.twoDigits))
    }
}

// MARK: - HealthKit Permission Denied View

private struct HealthKitDeniedView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Health Access Required", systemImage: "heart.slash")
        } description: {
            Text("ShareMyRun needs access to your workout data to display your activities. Please enable Health access in Settings.")
        } actions: {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Health access required. ShareMyRun needs access to your workout data. Tap to open Settings.")
    }
}

// MARK: - Loading View

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading workouts...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State View

private struct EmptyStateView: View {
    let filter: WorkoutTypeFilter

    var body: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: emptyIcon)
        } description: {
            Text(emptyDescription)
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .all:
            return "No Workouts"
        case .type(let workoutType):
            return "No \(workoutType.displayName) Workouts"
        }
    }

    private var emptyIcon: String {
        switch filter {
        case .all:
            return "figure.run"
        case .type(let workoutType):
            return workoutType.iconName
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .all:
            return "Your workouts from Apple Health will appear here. Pull down to refresh."
        case .type(let workoutType):
            return "No \(workoutType.displayName.lowercased()) workouts found. Try a different filter or pull down to refresh."
        }
    }
}

// MARK: - Preview

#Preview("With Workouts") {
    WorkoutListView()
        .modelContainer(for: [Workout.self, ShareConfiguration.self], inMemory: true)
}

#Preview("Empty State") {
    WorkoutListView()
        .modelContainer(for: [Workout.self, ShareConfiguration.self], inMemory: true)
}
