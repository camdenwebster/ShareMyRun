//
//  UserSubscription.swift
//  ShareMyRun
//
//  Created by Loki Mode on 1/18/26.
//

import Foundation
import SwiftData

/// SwiftData model tracking user's Pro subscription status
/// Stubbed for MVP - actual StoreKit integration will come later
@Model
final class UserSubscription {
    /// Whether the user has an active Pro subscription
    var isPro: Bool

    /// When the Pro subscription expires (nil for non-Pro users)
    var expirationDate: Date?

    /// When the subscription record was created
    var createdAt: Date

    /// When the subscription was last verified
    var lastVerifiedAt: Date

    // MARK: - Computed Properties

    /// Whether the Pro subscription is currently active
    var isProActive: Bool {
        guard isPro else { return false }
        guard let expiration = expirationDate else { return isPro }
        return expiration > Date()
    }

    // MARK: - Initialization

    init(isPro: Bool = false, expirationDate: Date? = nil) {
        self.isPro = isPro
        self.expirationDate = expirationDate
        self.createdAt = Date()
        self.lastVerifiedAt = Date()
    }

    // MARK: - Default

    /// Creates the default free subscription
    static func defaultSubscription() -> UserSubscription {
        UserSubscription(isPro: false)
    }
}

/// Protocol for subscription service operations
protocol SubscriptionServiceProtocol: Sendable {
    /// Gets the current subscription status
    func getSubscription() async -> UserSubscription

    /// Whether the user has Pro features
    var isPro: Bool { get async }

    /// Initiates the purchase flow (stubbed)
    func purchasePro() async throws

    /// Restores previous purchases (stubbed)
    func restorePurchases() async throws
}

/// Mock implementation for MVP - always returns non-Pro
final class MockSubscriptionService: SubscriptionServiceProtocol, @unchecked Sendable {
    nonisolated(unsafe) var mockIsPro: Bool = false

    private var effectiveIsPro: Bool {
        #if DEBUG
        true
        #else
        mockIsPro
        #endif
    }

    func getSubscription() async -> UserSubscription {
        UserSubscription(isPro: effectiveIsPro)
    }

    var isPro: Bool {
        get async { effectiveIsPro }
    }

    func purchasePro() async throws {
        // Stubbed - will implement StoreKit in future
        throw SubscriptionError.notImplemented
    }

    func restorePurchases() async throws {
        // Stubbed - will implement StoreKit in future
        throw SubscriptionError.notImplemented
    }
}

/// Subscription-related errors
enum SubscriptionError: Error, LocalizedError {
    case notImplemented
    case purchaseFailed
    case restoreFailed
    case noActiveSubscription

    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Pro subscriptions are coming soon!"
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .restoreFailed:
            return "Could not restore purchases. Please try again."
        case .noActiveSubscription:
            return "No active subscription found."
        }
    }
}
