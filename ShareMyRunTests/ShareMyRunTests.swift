//
//  ShareMyRunTests.swift
//  ShareMyRunTests
//
//  Created by Camden Webster on 1/18/26.
//

import Testing
@testable import ShareMyRun

@Suite("Subscription Tests")
struct ShareMyRunTests {
    @Test("Mock subscription service unlocks Pro in debug builds")
    func mockSubscriptionServiceUnlocksProInDebugBuilds() async {
        let service = MockSubscriptionService()
        let isPro = await service.isPro
        let subscription = await service.getSubscription()

        #if DEBUG
        #expect(isPro == true)
        #expect(subscription.isPro == true)
        #else
        #expect(isPro == false)
        #expect(subscription.isPro == false)
        #endif
    }
}
