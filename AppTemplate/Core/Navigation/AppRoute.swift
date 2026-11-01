//
//  AppRoute.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

protocol AppRoute: Hashable, Codable, Sendable, Identifiable {}

// Lets a route bind straight to .sheet(item:) and .fullScreenCover(item:).
extension AppRoute {
    var id: Self { self }
}

enum AuthRoute: AppRoute {
    case register
    case forgotPassword
    case resetPassword(token: String)
}

// Every screen behind the login lives in one stack rooted at Home, in the order the Next button walks them.
enum DashboardRoute: AppRoute {

    case favorites
    case profile
    case settings

    // The screen reached by the Next button, or nil on the last screen in the chain.
    var next: DashboardRoute? {
        switch self {
        case .favorites: .profile
        case .profile: .settings
        case .settings: nil
        }
    }

    // Home is the root, so the first Next button is the only one that isn't described by a route.
    static let firstScreen: DashboardRoute = .favorites
}
