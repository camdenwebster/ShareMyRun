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
    @ScaledMetric(relativeTo: .body) private var customizationSheetHeight = 430

    init(workout: Workout) {
        self.workout = workout
        self._viewModel = State(initialValue: ShareEditorViewModel(workout: workout))
    }

    var body: some View {
        VStack(spacing: 0) {
            PreviewArea(viewModel: viewModel)
                .frame(maxHeight: .infinity)

            Divider()

            CustomizationSheet(
                viewModel: viewModel,
                selectedPhotoItem: $selectedPhotoItem,
                selectedTab: $selectedCustomizationTab
            )
            .frame(height: customizationSheetHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
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
                ShareSheet(image: image)
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
                .clipShape(.rect(cornerRadius: 12))
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
    @AppStorage(SharePrivacySettings.removeWatermarkKey) private var removeWatermark = false

    var body: some View {
        GeometryReader { geometry in
            let metrics = ShareImagePreviewMetrics(
                previewSize: geometry.size,
                outputFormat: viewModel.outputFormat,
                baseFontSize: viewModel.configuration.fontSize
            )

            ZStack {
                backgroundView(metrics: metrics)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                if viewModel.configuration.textPosition != .center {
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black.opacity(0.56)],
                        startPoint: gradientStartPoint,
                        endPoint: gradientEndPoint
                    )
                    .frame(height: gradientHeight(for: geometry.size.height, metrics: metrics))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: gradientAlignment)
                }

                HStack(alignment: verticalAlignment, spacing: metrics.columnSpacing) {
                    if primaryStackOnLeading {
                        statisticsOverlay(metrics: metrics)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        featuredStatisticOverlay(metrics: metrics)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        featuredStatisticOverlay(metrics: metrics)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        statisticsOverlay(metrics: metrics)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(metrics.overlayPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: viewModel.configuration.textPosition.alignment)

                if !removeWatermark {
                    watermark(metrics: metrics)
                        .padding(metrics.watermarkPadding)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: viewModel.configuration.textPosition.watermarkAlignment
                        )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    @ViewBuilder
    private func backgroundView(metrics: ShareImagePreviewMetrics) -> some View {
        switch viewModel.configuration.backgroundType {
        case .routeMap:
            if let coordinates = viewModel.workout.routeCoordinates, coordinates.count >= 2 {
                RouteMapPreview(
                    coordinates: coordinates,
                    outputFormat: viewModel.outputFormat
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
    private func statisticsOverlay(metrics: ShareImagePreviewMetrics) -> some View {
        VStack(alignment: alignment, spacing: metrics.lineSpacing) {
            ForEach(sideStatistics, id: \.self) { stat in
                HStack(spacing: metrics.iconSpacing) {
                    Image(systemName: stat.iconName)
                    Text(stat.format(value: stat.getValue(from: viewModel.workout)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(overlayFont(size: metrics.valueFontSize, weight: .semibold))
                .foregroundStyle(viewModel.configuration.textColor)
                .shadow(
                    color: .black.opacity(0.5),
                    radius: metrics.shadowRadius,
                    x: metrics.shadowOffset,
                    y: metrics.shadowOffset
                )
            }
        }
    }

    @ViewBuilder
    private func featuredStatisticOverlay(metrics: ShareImagePreviewMetrics) -> some View {
        if let featuredStatistic {
            VStack(alignment: .center, spacing: metrics.featuredSpacing) {
                Text(featuredStatistic.format(value: featuredStatistic.getValue(from: viewModel.workout)))
                    .font(overlayFont(size: metrics.featuredValueFontSize, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(featuredStatistic.displayName.uppercased())
                    .font(overlayFont(size: metrics.featuredLabelFontSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .multilineTextAlignment(primaryStackOnLeading ? .trailing : .leading)
            .foregroundStyle(viewModel.configuration.textColor)
            .shadow(
                color: .black.opacity(0.55),
                radius: metrics.shadowRadius,
                x: metrics.shadowOffset,
                y: metrics.shadowOffset
            )
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

    private func gradientHeight(
        for containerHeight: CGFloat,
        metrics: ShareImagePreviewMetrics
    ) -> CGFloat {
        let textHeight: CGFloat
        if sideStatistics.isEmpty {
            textHeight = 0
        } else {
            textHeight =
                (CGFloat(sideStatistics.count) * metrics.valueFontSize)
                + (CGFloat(max(sideStatistics.count - 1, 0)) * metrics.lineSpacing)
        }

        let featuredHeight = featuredStatistic == nil
            ? 0
            : metrics.featuredValueFontSize + metrics.featuredLabelFontSize + metrics.featuredSpacing

        let contentHeight = max(textHeight, featuredHeight)
        let minimumHeight: CGFloat = containerHeight * 0.40
        let preferredHeight = contentHeight + (containerHeight * 0.12)

        return min(containerHeight * 0.75, max(minimumHeight, preferredHeight))
    }

    private func watermark(metrics: ShareImagePreviewMetrics) -> some View {
        Text("ShareMyRun")
            .font(.system(size: metrics.watermarkFontSize, weight: .medium))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, metrics.watermarkHorizontalInset)
            .padding(.vertical, metrics.watermarkVerticalInset)
            .background(.black.opacity(0.24), in: Capsule())
            .shadow(
                color: .black.opacity(0.45),
                radius: metrics.shadowRadius,
                x: 0,
                y: metrics.shadowOffset
            )
    }
}

private struct ShareImagePreviewMetrics {
    let previewSize: CGSize
    let outputFormat: ImageOutputFormat
    let baseFontSize: CGFloat

    private var outputScale: CGFloat {
        guard outputFormat.size.width > 0 else { return 0 }
        return previewSize.width / outputFormat.size.width
    }

    private var designScale: CGFloat {
        previewSize.width / 375
    }

    var valueFontSize: CGFloat {
        baseFontSize * designScale
    }

    var featuredValueFontSize: CGFloat {
        valueFontSize * 1.85
    }

    var featuredLabelFontSize: CGFloat {
        valueFontSize * 0.60
    }

    var overlayPadding: CGFloat {
        16 * designScale
    }

    var watermarkPadding: CGFloat {
        12 * designScale
    }

    var watermarkHorizontalInset: CGFloat {
        watermarkFontSize * 0.55
    }

    var watermarkVerticalInset: CGFloat {
        watermarkFontSize * 0.35
    }

    var columnSpacing: CGFloat {
        12 * designScale
    }

    var lineSpacing: CGFloat {
        8 * outputScale
    }

    var iconSpacing: CGFloat {
        10 * outputScale
    }

    var featuredSpacing: CGFloat {
        6 * outputScale
    }

    var shadowRadius: CGFloat {
        3 * outputScale
    }

    var shadowOffset: CGFloat {
        outputScale
    }

    var watermarkFontSize: CGFloat {
        previewSize.width / 40
    }
}

private struct RouteMapPreview: View {
    let coordinates: [RouteCoordinate]
    let outputFormat: ImageOutputFormat
    @AppStorage(SharePrivacySettings.routeRedactionDistanceKey)
    private var routeRedactionDistanceSliderValue: Double = RouteRedactionDistance.defaultValue.sliderValue
    @State private var renderedImage: UIImage?
    @State private var isRendering = false

    var body: some View {
        ZStack {
            if let renderedImage {
                Image(uiImage: renderedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.systemGray6)

                if isRendering {
                    ProgressView()
                        .padding(12)
                        .background(.ultraThinMaterial, in: Capsule())
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Loading Map")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task(id: renderRequestID) {
            await renderPreview()
        }
    }

    private var renderRequestID: String {
        let first = coordinates.first.map { "\($0.latitude),\($0.longitude)" } ?? "none"
        let last = coordinates.last.map { "\($0.latitude),\($0.longitude)" } ?? "none"
        return [
            outputFormat.rawValue,
            String(routeRedactionDistanceSliderValue),
            String(coordinates.count),
            first,
            last
        ]
        .joined(separator: "|")
    }

    private func renderPreview() async {
        guard coordinates.count >= 2 else {
            renderedImage = nil
            return
        }

        isRendering = true
        defer { isRendering = false }

        let size = outputFormat.size
        let configuration = RouteMapRenderer.Configuration(
            size: size,
            routeColor: .systemBlue,
            routeLineWidth: size.width / 270,
            mapType: .standard,
            padding: UIEdgeInsets(top: 60, left: 60, bottom: 60, right: 60),
            showMarkers: true,
            redactionDistance: RouteRedactionDistance(sliderValue: routeRedactionDistanceSliderValue).meters
        )

        do {
            renderedImage = try await RouteMapRenderer().render(
                coordinates: coordinates,
                configuration: configuration
            )
        } catch {
            renderedImage = nil
        }
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
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Font")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 6
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
                            .padding(.vertical, 4)
                            .background(viewModel.configuration.font == font ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(font.displayName) font")
                        .accessibilityAddTraits(viewModel.configuration.font == font ? .isSelected : [])
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
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

            VStack(alignment: .leading, spacing: 4) {
                Text("Position")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    spacing: 6
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
                                .padding(.vertical, 5)
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

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
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
