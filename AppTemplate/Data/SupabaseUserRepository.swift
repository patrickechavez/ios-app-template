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
// the client already uses for the signed-in session.
nonisolated struct SupabaseUserRepository: UserRepository {

    private let api: any APIClient

    init(api: any APIClient) {
        self.api = api
    }

    func currentUser() async throws -> User {
        let response: SupabaseUserResponse = try await api.get(APIRoute.Auth.currentUser)
        return response.user
    }

    func updateProfile(_ user: User) async throws -> User {
        // Deliberately omits email — sending it would trigger Supabase's
        // change-email confirmation flow even when it hasn't changed.
        let body = SupabaseUpdateUserRequest(
            data: SupabaseUpdateUserRequest.Metadata(
                firstName: user.firstName,
                lastName: user.lastName,
                username: user.username
            )
        )
        let endpoint = try Endpoint(APIRoute.Auth.currentUser, method: .put, body: .json(body))
        let response: SupabaseUserResponse = try await api.send(endpoint)
        return response.user
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

// MARK: - Wire types

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

// Supabase's user object: id/email at the top level, everything from
// signup's `data` nested under user_metadata with the same keys.
private struct SupabaseUserResponse: Decodable {
    let id: UUID
    let email: String
    let userMetadata: Metadata

    struct Metadata: Decodable {
        let firstName: String?
        let lastName: String?
        let username: String?

        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case lastName = "last_name"
            case username
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, email
        case userMetadata = "user_metadata"
    }

    var user: User {
        User(
            id: id,
            username: userMetadata.username ?? "",
            email: email,
            firstName: userMetadata.firstName ?? "",
            lastName: userMetadata.lastName ?? "",
            // No avatar wiring yet — uploadAvatar throws .notSupported.
            image: nil
        )
    }
}
