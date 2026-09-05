//
//  UserRepository.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation
import UIKit

protocol UserRepository: Sendable {
    func currentUser() async throws -> User
    func updateProfile(_ user: User) async throws -> User
    func uploadAvatar(_ image: UIImage, compression: ImageCompression) async throws -> User
    func registerForPushNotifications(token: String) async throws
    func unregisterForPushNotifications(token: String) async throws
}

extension UserRepository {

    func uploadAvatar(_ image: UIImage) async throws -> User {
        try await uploadAvatar(image, compression: .profile)
    }
}

nonisolated struct LiveUserRepository: UserRepository {

    private let api: any APIClient

    init(api: any APIClient) {
        self.api = api
    }

    func currentUser() async throws -> User {
        try await api.get(APIRoute.Auth.currentUser)
    }

    // Supabase updates a user via PUT auth/v1/user with changed fields
    // nested under "data" — not a PATCH to a users/{id} resource, which
    // doesn't exist. Email is deliberately omitted: sending it would
    // trigger Supabase's change-email confirmation even when it hasn't
    // changed.
    func updateProfile(_ user: User) async throws -> User {
        let body = UpdateUserRequest(
            data: UpdateUserRequest.Metadata(
                firstName: user.userMetadata.firstName,
                lastName: user.userMetadata.lastName,
                username: user.userMetadata.username
            )
        )
        let endpoint = try Endpoint(APIRoute.Auth.currentUser, method: .put, body: .json(body))
        return try await api.send(endpoint)
    }

    // Supabase Storage uploads are raw binary POSTs to a bucket path, not
    // this multipart flow, and need a bucket choice plus a follow-up call
    // to store the resulting URL in user_metadata — real new scope, not
    // an endpoint swap.
    func uploadAvatar(_ image: UIImage, compression: ImageCompression) async throws -> User {
        throw APIError.notSupported(message: "Avatar upload isn't implemented for Supabase yet.")
    }

    // No Supabase-native equivalent — would need a custom devices table.
    func registerForPushNotifications(token: String) async throws {
        throw APIError.notSupported(message: "Push registration isn't implemented for Supabase yet.")
    }

    func unregisterForPushNotifications(token: String) async throws {
        throw APIError.notSupported(message: "Push registration isn't implemented for Supabase yet.")
    }
}

// The one shape User itself can't represent — Supabase's update-user
// request nests changed fields under "data", not User's own layout.
private struct UpdateUserRequest: Encodable {
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
