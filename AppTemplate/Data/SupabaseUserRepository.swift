//
//  SupabaseUserRepository.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation
import UIKit

// Speaks Supabase Auth's user object instead of a generic REST backend.
// Profile fields live in auth.users.user_metadata — no separate table —
// so both reading and writing go through the same /auth/v1/user endpoint
// the client already uses for the signed-in session. User itself now
// mirrors that shape, so reads need no translation — only the update
// *request* still needs its own shape (see SupabaseUpdateUserRequest
// below), since Supabase expects {"data": {...}}, not User's own shape.
nonisolated struct SupabaseUserRepository: UserRepository {

    private let api: any APIClient

    // currentUser() ends up identical to Live's version now that User
    // decodes Supabase's shape directly — delegate rather than repeat it.
    private let live: LiveUserRepository

    init(api: any APIClient) {
        self.api = api
        self.live = LiveUserRepository(api: api)
    }

    func currentUser() async throws -> User {
        try await live.currentUser()
    }

    func updateProfile(_ user: User) async throws -> User {
        // Deliberately omits email — sending it would trigger Supabase's
        // change-email confirmation flow even when it hasn't changed.
        let body = SupabaseUpdateUserRequest(
            data: SupabaseUpdateUserRequest.Metadata(
                firstName: user.userMetadata.firstName,
                lastName: user.userMetadata.lastName,
                username: user.userMetadata.username
            )
        )
        let endpoint = try Endpoint(APIRoute.Auth.currentUser, method: .put, body: .json(body))
        return try await api.send(endpoint)
    }

    func uploadAvatar(_ image: UIImage, compression: ImageCompression) async throws -> User {
        throw APIError.notSupported(message: "Avatar upload isn't implemented for Supabase yet.")
    }

    func registerForPushNotifications(token: String) async throws {
        throw APIError.notSupported(message: "Push registration isn't implemented for Supabase yet.")
    }

    func unregisterForPushNotifications(token: String) async throws {
        throw APIError.notSupported(message: "Push registration isn't implemented for Supabase yet.")
    }
}

// The one shape User itself can't represent — Supabase's update-user
// request nests changed fields under "data", not User's own layout.
private struct SupabaseUpdateUserRequest: Encodable {
    let data: Metadata

    struct Metadata: Encodable {
        let firstName: String
        let lastName: String
        let username: String

        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case lastName = "last_name"
            case username
        }
    }
}
