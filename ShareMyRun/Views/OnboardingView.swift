//
//  OnboardingView.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import SwiftUI
import HealthKit

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage: Int = 0
    @State private var healthKitRequested: Bool = false
    @State private var healthKitAuthorized: Bool = false

    private let healthService = HealthService()

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                WelcomePage()
                    .tag(0)

                HealthKitPage(
                    healthKitRequested: $healthKitRequested,
                    healthKitAuthorized: $healthKitAuthorized,
                    requestPermission: requestHealthKitPermission
                )
                .tag(1)

                GetStartedPage(onComplete: completeOnboarding)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.accentColor : Color(.systemGray4))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)

            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentPage < 2 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }

    private func requestHealthKitPermission() {
        Task {
            do {
                let status = try await healthService.requestAuthorization()
                await MainActor.run {
                    healthKitRequested = true
                    healthKitAuthorized = status == .authorized
                }
            } catch {
                await MainActor.run {
                    healthKitRequested = true
                    healthKitAuthorized = false
                }
            }
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

// MARK: - Welcome Page

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.tint)

            Text("Welcome to ShareMyRun")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Create beautiful, customizable images of your workouts to share with friends and on social media.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Feature highlights
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "heart.text.square",
                    title: "Import from Health",
                    description: "Access your workouts from Apple Health"
                )

                FeatureRow(
                    icon: "paintbrush",
                    title: "Fully Customizable",
                    description: "Choose stats, backgrounds, and styling"
                )

                FeatureRow(
                    icon: "square.and.arrow.up",
                    title: "Share Anywhere",
                    description: "Export to any app or save to photos"
                )
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - HealthKit Page

private struct HealthKitPage: View {
    @Binding var healthKitRequested: Bool
    @Binding var healthKitAuthorized: Bool
    let requestPermission: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red)

            Text("Connect to Apple Health")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("ShareMyRun needs access to your workout data to display your activities and their statistics.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if !healthKitRequested {
                Button {
                    requestPermission()
                } label: {
                    Label("Allow Health Access", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)
            } else if healthKitAuthorized {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Health access granted!")
                }
                .font(.headline)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Access not granted")
                    }
                    .font(.headline)

                    Text("You can enable access later in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("We only read your workout data - we never write or modify anything.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Get Started Page

private struct GetStartedPage: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Start creating beautiful shareable images of your workouts.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                onComplete()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
