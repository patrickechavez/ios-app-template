//
//  AppNavigator.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Observation
import SwiftUI
import os

@Observable
@MainActor
final class AppNavigator {

    let main = Router<MainRoute>()
    let auth = Router<AuthRoute>()

    private(set) var pendingLink: DeepLink?

    @ObservationIgnored private let parser: DeepLinkParser

    init(parser: DeepLinkParser = DeepLinkParser()) {
        self.parser = parser
    }

    @discardableResult
    func open(_ url: URL, isAuthenticated: Bool) -> Bool {
        guard let link = parser.parse(url) else {
            AppLogger.navigation.breadcrumb("Ignoring unhandled URL: \(url.absoluteString)")
            return false
        }
        open(link, isAuthenticated: isAuthenticated)
        return true
    }

    @discardableResult
    func open(notification payload: [AnyHashable: Any], isAuthenticated: Bool) -> Bool {
        guard let link = parser.parse(notificationPayload: payload) else { return false }
        open(link, isAuthenticated: isAuthenticated)
        return true
    }

    func open(_ link: DeepLink, isAuthenticated: Bool) {
        guard isAuthenticated || link.isPublic else {

            AppLogger.navigation.breadcrumb("Deferring deep link until signed in: \(link.path)")
            pendingLink = link
            return
        }

        apply(link)
    }

    func resumePendingLink() {
        guard let link = pendingLink else { return }
        pendingLink = nil
        AppLogger.navigation.breadcrumb("Resuming deferred deep link: \(link.path)")
        apply(link)
    }

    func clearPendingLink() {
        pendingLink = nil
    }

    func reset() {
        main.popToRoot()
        auth.popToRoot()
        pendingLink = nil
    }

    private func apply(_ link: DeepLink) {
        switch link {
        case .home:
            main.popToRoot()

        // Lands on the screen with the screens before it still underneath, so Back walks the usual chain.
        case .profile:
            main.set([.favorites, .profile])

        case .settings:
            main.set([.favorites, .profile, .settings])

        case let .resetPassword(token):

            auth.set([.resetPassword(token: token)])
        }
    }
}
