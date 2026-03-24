//
//  ShareEditorView.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import MapKit

struct ShareEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let workout: Workout

    @State private var viewModel: ShareEditorViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedCustomizationTab = 0
    @State private var showFormatPicker = false

    init(workout: Workout) {
        self.workout = workout
        self._viewModel = State(initialValue: ShareEditorViewModel(workout: workout))
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = editorLayout(for: geometry.size, selectedTab: selectedCustomizationTab)

            VStack(spacing: 0) {
                PreviewArea(viewModel: viewModel)
                    .frame(height: layout.previewHeight)

                Divider()

                CustomizationSheet(
                    viewModel: viewModel,
                    selectedPhotoItem: $selectedPhotoItem,
                    selectedTab: $selectedCustomizationTab
                )
                    .frame(height: layout.controlsHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("Share Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        Task { await viewModel.share() }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        Task { await viewModel.saveToPhotos() }
                    } label: {
                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                    }

                    Divider()

                    Picker("Format", selection: $viewModel.outputFormat) {
                        ForEach(ImageOutputFormat.allCases) { format in
                            Label(format.displayName, systemImage: format.iconName)
                                .tag(format)
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share options")
            }
        }
        .task {
            viewModel.setModelContext(modelContext)
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                await loadSelectedPhoto(from: newValue)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .alert("Saved!", isPresented: $viewModel.showSaveConfirmation) {
            Button("OK") { }
        } message: {
            Text("Image saved to your photo library.")
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let image = viewModel.generatedImage {
                ShareSheet(image: image, workout: workout)
            }
        }
    }

    private func loadSelectedPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                viewModel.selectedPhoto = image
                viewModel.setBackgroundType(.selectedPhoto)
            }
        } catch {
            viewModel.clearError()
        }
    }

    private func editorLayout(for size: CGSize, selectedTab: Int) -> (previewHeight: CGFloat, controlsHeight: CGFloat) {
        let isStyleTabSelected = selectedTab == 2
        let minControlsHeight: CGFloat = isStyleTabSelected ? 300 : 270
        let maxControlsHeight: CGFloat = isStyleTabSelected ? 380 : 360
        let fallbackMinControlsHeight: CGFloat = isStyleTabSelected ? 250 : 220
        let minimumPreviewHeight: CGFloat = 180

        var controlsHeight = min(max(size.height * 0.42, minControlsHeight), maxControlsHeight)

        if size.height - controlsHeight < minimumPreviewHeight {
            controlsHeight = max(fallbackMinControlsHeight, size.height - minimumPreviewHeight)
        }

        controlsHeight = min(max(controlsHeight, 0), size.height)
        let previewHeight = max(0, size.height - controlsHeight)

        return (previewHeight, controlsHeight)
    }
}

// MARK: - Preview Area

private struct PreviewArea: View {
    let viewModel: ShareEditorViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemGroupedBackground)

                PreviewContent(viewModel: viewModel)
                .frame(
                    width: previewWidth(for: geometry),
                    height: previewHeight(for: geometry)
                )
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 10)

                if viewModel.isGeneratingImage {
                    ProgressView()
                        .padding(12)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }

    private func previewWidth(for geometry: GeometryProxy) -> CGFloat {
        let maxWidth = max(0, geometry.size.width - 32)
        let maxHeight = max(0, geometry.size.height - 32)
        let aspectRatio = viewModel.outputFormat.aspectRatio

        guard maxWidth > 0, maxHeight > 0, aspectRatio.isFinite, aspectRatio > 0 else {
            return 0
        }

        if maxWidth / maxHeight > aspectRatio {
            return maxHeight * aspectRatio
        } else {
            return maxWidth
        }
    }

    private func previewHeight(for geometry: GeometryProxy) -> CGFloat {
        let maxWidth = max(0, geometry.size.width - 32)
        let maxHeight = max(0, geometry.size.height - 32)
        let aspectRatio = viewModel.outputFormat.aspectRatio

        guard maxWidth > 0, maxHeight > 0, aspectRatio.isFinite, aspectRatio > 0 else {
            return 0
        }

        if maxWidth / maxHeight > aspectRatio {
            return maxHeight
        } else {
            return maxWidth / aspectRatio
        }
    }
}

// MARK: - Preview Content

private struct PreviewContent: View {
    let viewModel: ShareEditorViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                if viewModel.configuration.textPosition != .center {
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black.opacity(0.56)],
                        startPoint: gradientStartPoint,
                        endPoint: gradientEndPoint
                    )
                    .frame(height: gradientHeight(for: geometry.size.height))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: gradientAlignment)
                }

                HStack(alignment: verticalAlignment, spacing: 12) {
                    if primaryStackOnLeading {
                        statisticsOverlay
                            .frame(maxWidth: .infinity, alignment: .leading)
                        featuredStatisticOverlay
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        featuredStatisticOverlay
                            .frame(maxWidth: .infinity, alignment: .leading)
                        statisticsOverlay
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: viewModel.configuration.textPosition.alignment)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch viewModel.configuration.backgroundType {
        case .routeMap:
            if let coordinates = viewModel.workout.routeCoordinates, coordinates.count >= 2 {
                RouteMapPreview(
                    coordinates: coordinates,
                    redactionDistance: viewModel.configuration.routeRedactionDistance
                )
            } else {
                ZStack {
                    Color.gray.opacity(0.2)
                    VStack {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Route Data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .lastPhoto:
            if let photo = viewModel.lastPhotoPreview {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.gray.opacity(0.3)
                    VStack {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Photo Background")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .selectedPhoto:
            if let photo = viewModel.selectedPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.gray.opacity(0.3)
                    VStack {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Photo Background")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statisticsOverlay: some View {
        VStack(alignment: alignment, spacing: 4) {
            ForEach(sideStatistics, id: \.self) { stat in
                HStack(spacing: 4) {
                    Image(systemName: stat.iconName)
                    Text(stat.format(value: stat.getValue(from: viewModel.workout)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(overlayFont(size: viewModel.configuration.fontSize, weight: .semibold))
                .foregroundStyle(viewModel.configuration.textColor)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
            }
        }
    }

    @ViewBuilder
    private var featuredStatisticOverlay: some View {
        if let featuredStatistic {
            VStack(alignment: .center, spacing: 2) {
                Text(featuredStatistic.format(value: featuredStatistic.getValue(from: viewModel.workout)))
                    .font(overlayFont(size: viewModel.configuration.fontSize * 1.65, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(featuredStatistic.displayName.uppercased())
                    .font(overlayFont(size: viewModel.configuration.fontSize * 0.60, weight: .semibold))
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .multilineTextAlignment(primaryStackOnLeading ? .trailing : .leading)
            .foregroundStyle(viewModel.configuration.textColor)
            .shadow(color: .black.opacity(0.55), radius: 2, x: 1, y: 1)
        }
    }

    private var alignment: HorizontalAlignment {
        switch viewModel.configuration.textPosition {
        case .topLeft, .bottomLeft:
            return .leading
        case .topRight, .bottomRight:
            return .trailing
        case .center:
            return .center
        }
    }

    private func overlayFont(size: CGFloat, weight: Font.Weight) -> Font {
        switch viewModel.configuration.font {
        case .system:
            return .system(size: size, weight: weight, design: .default)
        case .systemRounded:
            return .system(size: size, weight: weight, design: .rounded)
        default:
            return .custom(viewModel.configuration.font.fontName, size: size)
        }
    }

    private var featuredStatistic: StatisticType? {
        let featured = viewModel.configuration.featuredStatistic
        guard viewModel.configuration.selectedStatistics.contains(featured) else {
            return nil
        }

        let value = featured.getValue(from: viewModel.workout)
        return featured.format(value: value) == "N/A" ? nil : featured
    }

    private var sideStatistics: [StatisticType] {
        guard let featuredStatistic else {
            return viewModel.configuration.selectedStatistics
        }
        return viewModel.configuration.selectedStatistics.filter { $0 != featuredStatistic }
    }

    private var primaryStackOnLeading: Bool {
        switch viewModel.configuration.textPosition {
        case .topLeft, .bottomLeft:
            return true
        case .topRight, .bottomRight:
            return false
        case .center:
            return true
        }
    }

    private var verticalAlignment: VerticalAlignment {
        switch viewModel.configuration.textPosition {
        case .topLeft, .topRight:
            return .top
        case .bottomLeft, .bottomRight:
            return .bottom
        case .center:
            return .center
        }
    }

    private var gradientAlignment: Alignment {
        switch viewModel.configuration.textPosition {
        case .topLeft, .topRight:
            return .top
        case .bottomLeft, .bottomRight:
            return .bottom
        case .center:
            return .center
        }
    }

    private var gradientStartPoint: UnitPoint {
        switch viewModel.configuration.textPosition {
        case .topLeft, .topRight:
            return .bottom
        case .bottomLeft, .bottomRight:
            return .top
        case .center:
            return .top
        }
    }

    private var gradientEndPoint: UnitPoint {
        switch viewModel.configuration.textPosition {
        case .topLeft, .topRight:
            return .top
        case .bottomLeft, .bottomRight:
            return .bottom
        case .center:
            return .bottom
        }
    }

    private func gradientHeight(for containerHeight: CGFloat) -> CGFloat {
        let statCount = max(sideStatistics.count, 1)
        let textHeight = (CGFloat(statCount) * viewModel.configuration.fontSize * 1.3) + 32
        let featuredHeight = viewModel.configuration.fontSize * 2.5
        return min(containerHeight * 0.75, max(containerHeight * 0.40, max(textHeight, featuredHeight) + 32))
    }
}

private struct RouteMapPreview: View {
    let coordinates: [RouteCoordinate]
    let redactionDistance: RouteRedactionDistance

    var body: some View {
        let clCoordinates = RouteMapRenderer.redactedCoordinates(
            from: coordinates.map(\.coordinate),
            distance: redactionDistance.meters
        )

        Map(initialPosition: .region(region(for: clCoordinates)), interactionModes: []) {
            MapPolyline(coordinates: clCoordinates)
                .stroke(Color.blue, lineWidth: 4)

            if let start = clCoordinates.first {
                Annotation("Start", coordinate: start) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        }
                }
            }

            if let end = clCoordinates.last {
                Annotation("End", coordinate: end) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        }
                }
            }
        }
    }

    private func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        var minLatitude = first.latitude
        var maxLatitude = first.latitude
        var minLongitude = first.longitude
        var maxLongitude = first.longitude

        for coordinate in coordinates {
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
            minLongitude = min(minLongitude, coordinate.longitude)
            maxLongitude = max(maxLongitude, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let latitudeDelta = max((maxLatitude - minLatitude) * 1.35, 0.005)
        let longitudeDelta = max((maxLongitude - minLongitude) * 1.35, 0.005)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

// MARK: - Customization Sheet

private struct CustomizationSheet: View {
    let viewModel: ShareEditorViewModel
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var selectedTab: Int

    var body: some View {
        VStack(spacing: 10) {
            Picker("Options", selection: $selectedTab) {
                Text("Stats").tag(0)
                Text("Background").tag(1)
                Text("Style").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 10)

            TabView(selection: $selectedTab) {
                StatisticsTab(viewModel: viewModel)
                    .tag(0)

                BackgroundTab(viewModel: viewModel, selectedPhotoItem: $selectedPhotoItem)
                    .tag(1)

                StyleTab(viewModel: viewModel)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.bottom, 10)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Statistics Tab

private struct StatisticsTab: View {
    let viewModel: ShareEditorViewModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(viewModel.availableStatistics, id: \.self) { stat in
                StatisticToggle(
                    stat: stat,
                    workout: viewModel.workout,
                    isSelected: viewModel.isStatisticSelected(stat),
                    isFeatured: viewModel.isFeaturedStatistic(stat),
                    isDisabled: !viewModel.canAddMoreStatistics && !viewModel.isStatisticSelected(stat)
                ) {
                    viewModel.toggleStatistic(stat)
                } onFeature: {
                    viewModel.setFeaturedStatistic(stat)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct StatisticToggle: View {
    let stat: StatisticType
    let workout: Workout
    let isSelected: Bool
    let isFeatured: Bool
    let isDisabled: Bool
    let action: () -> Void
    let onFeature: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(spacing: 2) {
                    Image(systemName: stat.iconName)
                        .font(.subheadline)

                    Text(stat.displayName)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(stat.format(value: stat.getValue(from: workout)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
            }

            Button(action: onFeature) {
                Image(systemName: isFeatured ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(isFeatured ? .yellow : .secondary)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel(isFeatured ? "Featured statistic" : "Mark as featured")
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityLabel("\(stat.displayName), \(isSelected ? "selected" : "not selected")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Background Tab

private struct BackgroundTab: View {
    let viewModel: ShareEditorViewModel
    @Binding var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                BackgroundOption(
                    type: .routeMap,
                    isSelected: viewModel.configuration.backgroundType == .routeMap,
                    isDisabled: !viewModel.isRouteMapAvailable
                ) {
                    viewModel.setBackgroundType(.routeMap)
                }

                BackgroundOption(
                    type: .lastPhoto,
                    isSelected: viewModel.configuration.backgroundType == .lastPhoto,
                    isDisabled: false
                ) {
                    viewModel.setBackgroundType(.lastPhoto)
                    Task { await viewModel.loadLastPhoto() }
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    BackgroundOptionContent(
                        type: .selectedPhoto,
                        isSelected: viewModel.configuration.backgroundType == .selectedPhoto
                    )
                }
            }
            .padding(.horizontal, 12)

            if viewModel.isRouteMapAvailable {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hide Start/End")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                        spacing: 8
                    ) {
                        ForEach(RouteRedactionDistance.allCases) { distance in
                            Button {
                                viewModel.setRouteRedactionDistance(distance)
                            } label: {
                                Text(distance.displayName)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        viewModel.configuration.routeRedactionDistance == distance
                                            ? Color.accentColor.opacity(0.2)
                                            : Color(.systemGray6)
                                    )
                                    .clipShape(.rect(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Hide \(distance.displayName) from each end")
                            .accessibilityAddTraits(
                                viewModel.configuration.routeRedactionDistance == distance ? .isSelected : []
                            )
                        }
                    }

                    Text("Moves the visible route start and finish away from your actual location.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
            }

            if !viewModel.isRouteMapAvailable {
                Text("Route map unavailable - this workout has no GPS data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct BackgroundOption: View {
    let type: BackgroundType
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BackgroundOptionContent(type: type, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

private struct BackgroundOptionContent: View {
    let type: BackgroundType
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: type.iconName)
                .font(.headline)

            Text(type.displayName)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .accessibilityLabel("\(type.displayName) background")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Style Tab

private struct StyleTab: View {
    let viewModel: ShareEditorViewModel

    var body: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Font")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    ForEach(OverlayFont.allCases) { font in
                        Button {
                            viewModel.setFont(font)
                        } label: {
                            VStack(spacing: 2) {
                                Text("Aa")
                                    .font(font.previewFont)
                                Text(font.displayName)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(viewModel.configuration.font == font ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(font.displayName) font")
                        .accessibilityAddTraits(viewModel.configuration.font == font ? .isSelected : [])
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Size")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(viewModel.configuration.fontSize))pt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { viewModel.configuration.fontSize },
                        set: { viewModel.setFontSize($0) }
                    ),
                    in: 12...32,
                    step: 1
                )
                .accessibilityLabel("Font size")
                .accessibilityValue("\(Int(viewModel.configuration.fontSize)) points")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Position")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    spacing: 8
                ) {
                    ForEach(TextPosition.allCases) { position in
                        Button {
                            viewModel.setTextPosition(position)
                        } label: {
                            Text(position.displayName)
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(viewModel.configuration.textPosition == position ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(position.displayName) text position")
                        .accessibilityAddTraits(viewModel.configuration.textPosition == position ? .isSelected : [])
                    }
                }
            }

            HStack {
                Text("Text Color")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                ColorPicker(
                    "Color",
                    selection: Binding(
                        get: { viewModel.configuration.textColor },
                        set: { viewModel.setTextColor($0) }
                    )
                )
                .labelsHidden()
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    let workout: Workout

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let caption = "\(workout.type.displayName) - \(workout.formattedDuration)"
        let items: [Any] = [image, caption]
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ShareEditorView(workout: Workout(
        healthKitID: "preview-123",
        type: .running,
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        distance: 5000,
        duration: 1865,
        calories: 450,
        averagePace: 480.0 / 1609.344
    ))
    .modelContainer(for: [Workout.self, ShareConfiguration.self], inMemory: true)
}
