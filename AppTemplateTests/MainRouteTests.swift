//
//  MainRouteTests.swift
//  AppTemplateTests
//

import Testing
@testable import AppTemplate

struct MainRouteTests {

    @Test func walksTheScreensInOrderFromHome() {
        #expect(MainRoute.firstScreen == .favorites)
        #expect(MainRoute.favorites.next == .profile)
        #expect(MainRoute.profile.next == .settings)
    }

    // Settings is the last screen, so it shows no Next button.
    @Test func endsTheChainAtSettings() {
        #expect(MainRoute.settings.next == nil)
    }
}
