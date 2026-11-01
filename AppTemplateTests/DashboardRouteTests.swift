//
//  DashboardRouteTests.swift
//  AppTemplateTests
//

import Testing
@testable import AppTemplate

struct DashboardRouteTests {

    @Test func walksTheScreensInOrderFromHome() {
        #expect(DashboardRoute.firstScreen == .favorites)
        #expect(DashboardRoute.favorites.next == .profile)
        #expect(DashboardRoute.profile.next == .settings)
    }

    // Settings is the last screen, so it shows no Next button.
    @Test func endsTheChainAtSettings() {
        #expect(DashboardRoute.settings.next == nil)
    }
}
