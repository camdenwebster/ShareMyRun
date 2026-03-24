//
//  AppModelContainer.swift
//  ShareMyRun
//
//  Created by Codex on 2/22/26.
//

import Foundation
import SwiftData

enum AppModelContainer {
    static var schema: Schema {
        Schema([
            Workout.self,
            ShareConfiguration.self,
            UserSubscription.self,
            AutoShareConfig.self,
        ])
    }

    static func make(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}
