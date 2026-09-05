//
//  APIRoute.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

enum APIRoute {

    enum Auth {
        // login and refresh are the same Supabase endpoint — ?grant_type=
        // on the request is what tells them apart.
        static let login = "auth/v1/token"
        static let refresh = "auth/v1/token"
        static let register = "auth/v1/signup"
        static let logout = "auth/v1/logout"
        static let currentUser = "auth/v1/user"
        static let requestPasswordReset = "auth/v1/recover"
        static let resetPassword = "auth/v1/user"
    }

    enum Users {
        static let avatar = "user/avatar"
        static func profile(_ id: String) -> String { "users/\(id)" }
    }

    enum System {

        static let versionCheck = "system/version"
    }

    enum Devices {

        static let register = "devices"
        static func unregister(_ token: String) -> String { "devices/\(token)" }
    }

    enum Items {
        static let list = "items"
        static let search = "items/search"
        static func detail(_ id: String) -> String { "items/\(id)" }
    }
}
