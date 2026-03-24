//
//  AutoShareJob.swift
//  ShareMyRun
//
//  Created by Codex on 2/22/26.
//

import Foundation

/// Persisted work item for automatic share image generation and delivery.
struct AutoShareJob: Codable, Equatable, Identifiable {
    let id: UUID
    var workoutHealthKitID: String
    var workoutEndDate: Date
    var status: AutoShareJobStatus
    var imageData: Data?
    var messageBody: String?
    var failureReason: String?
    var attemptCount: Int
    var createdAt: Date
    var lastAttemptAt: Date?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        workoutHealthKitID: String,
        workoutEndDate: Date,
        status: AutoShareJobStatus = .pending,
        imageData: Data? = nil,
        messageBody: String? = nil,
        failureReason: String? = nil,
        attemptCount: Int = 0,
        createdAt: Date = Date(),
        lastAttemptAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.workoutHealthKitID = workoutHealthKitID
        self.workoutEndDate = workoutEndDate
        self.status = status
        self.imageData = imageData
        self.messageBody = messageBody
        self.failureReason = failureReason
        self.attemptCount = attemptCount
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.updatedAt = updatedAt
    }
}

enum AutoShareJobStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case ready
    case failed
    case delivered

    var id: String { rawValue }
}
