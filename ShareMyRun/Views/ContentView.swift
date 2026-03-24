//
//  ContentView.swift
//  ShareMyRun
//
//  Created by Camden Webster on 1/18/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        WorkoutListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Workout.self,
                ShareConfiguration.self,
                UserSubscription.self,
                AutoShareConfig.self,
            ],
            inMemory: true
        )
}
