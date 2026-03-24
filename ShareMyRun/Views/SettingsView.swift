//
//  SettingsView.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SharePrivacySettings.removeWatermarkKey) private var removeWatermark = false
    @State private var subscriptionService: SubscriptionServiceProtocol = MockSubscriptionService()
    @State private var isPro: Bool = false
    @State private var showUpgradeAlert: Bool = false
    @State private var autoShareEnabled: Bool = false
    @State private var autoShareDeliveryMode: AutoShareDeliveryMode = .queueOnly
    @State private var autoShareImageFormat: AutoShareImageFormat = .square
    @State private var autoShareLookbackMinutes: Double = 180
    @State private var pendingJobCount: Int = 0
    @State private var readyJobCount: Int = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Remove Watermark", isOn: $removeWatermark)
                } header: {
                    Text("Sharing")
                } footer: {
                    Text("When enabled, shared images are exported without the ShareMyRun watermark.")
                }

                Section {
                    Toggle("Enable Auto-Share", isOn: $autoShareEnabled)

                    Picker("Delivery", selection: $autoShareDeliveryMode) {
                        ForEach(AutoShareDeliveryMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Picker("Image Format", selection: $autoShareImageFormat) {
                        ForEach(AutoShareImageFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }

                    Stepper(
                        "Lookback Window: \(Int(autoShareLookbackMinutes)) min",
                        value: $autoShareLookbackMinutes,
                        in: 30...720,
                        step: 15
                    )

                    HStack {
                        Text("Queued Jobs")
                        Spacer()
                        Text("\(pendingJobCount)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Ready Jobs")
                        Spacer()
                        Text("\(readyJobCount)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Auto-Share (Beta)")
                } footer: {
                    Text("Use Shortcuts automation: When Workout Ends -> Generate Latest Workout Share -> Send Message.")
                }

                Section("Privacy") {
                    RoutePrivacySettingView()
                }

                // Upgrade Section
                if !isPro {
                    Section {
                        Button {
                            showUpgradeAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                                Text("Upgrade to Pro")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("Coming Soon")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            Task {
                                do {
                                    try await subscriptionService.restorePurchases()
                                } catch {
                                    // Expected to fail in MVP
                                }
                            }
                        } label: {
                            Text("Restore Purchases")
                        }
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://sharemyrun.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://sharemyrun.app/terms")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Support Section
                Section("Support") {
                    Link(destination: URL(string: "mailto:support@sharemyrun.app")!) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Contact Support")
                        }
                    }

                    Link(destination: URL(string: "https://sharemyrun.app/faq")!) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("FAQ")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                isPro = await subscriptionService.isPro
                loadAutoShareSettings()
            }
            .onChange(of: autoShareEnabled) { _, _ in
                persistAutoShareSettings()
            }
            .onChange(of: autoShareDeliveryMode) { _, _ in
                persistAutoShareSettings()
            }
            .onChange(of: autoShareImageFormat) { _, _ in
                persistAutoShareSettings()
            }
            .onChange(of: autoShareLookbackMinutes) { _, _ in
                persistAutoShareSettings()
            }
            .alert("Pro Coming Soon", isPresented: $showUpgradeAlert) {
                Button("OK") { }
            } message: {
                Text("Pro subscriptions will be available in a future update. Stay tuned!")
            }
        }
    }

    private func loadAutoShareSettings() {
        do {
            let config = try fetchOrCreateAutoShareConfig()
            autoShareEnabled = config.isEnabled
            autoShareDeliveryMode = config.deliveryMode
            autoShareImageFormat = config.imageFormat
            autoShareLookbackMinutes = Double(config.lookbackWindowMinutes)
            refreshAutoShareCounts()
        } catch {
            print("Failed to load auto-share settings: \(error)")
        }
    }

    private func persistAutoShareSettings() {
        do {
            let config = try fetchOrCreateAutoShareConfig()
            config.isEnabled = autoShareEnabled
            config.deliveryMode = autoShareDeliveryMode
            config.imageFormat = autoShareImageFormat
            config.lookbackWindowMinutes = Int(autoShareLookbackMinutes)
            config.lastModified = Date()
            try modelContext.save()
        } catch {
            print("Failed to save auto-share settings: \(error)")
        }

        refreshAutoShareCounts()
    }

    private func refreshAutoShareCounts() {
        do {
            let config = try fetchOrCreateAutoShareConfig()
            let jobs = config.jobs
            pendingJobCount = jobs.filter { $0.status == .pending }.count
            readyJobCount = jobs.filter { $0.status == .ready }.count
        } catch {
            print("Failed to fetch auto-share queue counts: \(error)")
            pendingJobCount = 0
            readyJobCount = 0
        }
    }

    private func fetchOrCreateAutoShareConfig() throws -> AutoShareConfig {
        var descriptor = FetchDescriptor<AutoShareConfig>()
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let config = AutoShareConfig.defaultConfig()
        modelContext.insert(config)
        try modelContext.save()
        return config
    }
}

private struct RoutePrivacySettingView: View {
    @AppStorage(SharePrivacySettings.routeRedactionDistanceKey)
    private var routeRedactionDistanceSliderValue: Double = RouteRedactionDistance.defaultValue.sliderValue

    private var selectedDistance: RouteRedactionDistance {
        RouteRedactionDistance(sliderValue: routeRedactionDistanceSliderValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Hide Start/End")
                Spacer()
                Text(selectedDistance.displayName)
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: $routeRedactionDistanceSliderValue,
                in: 0...Double(RouteRedactionDistance.allCases.count - 1),
                step: 1
            ) {
                Text("Hide Start/End")
            } minimumValueLabel: {
                Text(RouteRedactionDistance.eighthMile.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text(RouteRedactionDistance.oneMile.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("Moves the visible route start and finish away from your actual location when sharing route maps.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
