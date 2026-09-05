//
//  SupabaseAuthRepository.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

// Speaks Supabase's Auth API (GoTrue) instead of a generic REST backend.
nonisolated struct SupabaseAuthRepository: AuthRepository {

    private let api: any APIClient

    init(api: any APIClient) {
        self.api = api
    }

    func login(username: String, password: String) async throws -> AuthTokens {
        // Supabase logs in with email — "username" here is really an email.
        let endpoint = Endpoint(
            APIRoute.Auth.login,
            method: .post,
            query: [URLQueryItem(name: "grant_type", value: "password")],
            body: try .json(SupabaseLoginRequest(email: username, password: password)),
            requiresAuth: false
        )
        let response: SupabaseAuthResponse = try await api.send(endpoint)
        return response.tokens
    }

    func register(_ request: RegisterRequest) async throws -> RegisterResponse {
        let body = SupabaseSignUpRequest(
            email: request.email,
            password: request.password,
            data: SupabaseSignUpRequest.Metadata(
                firstName: request.firstName,
                lastName: request.lastName,
                username: request.username,
                dateOfBirth: request.dateOfBirth
            )
        )
        let response: SupabaseSignUpResponse = try await api.post(
            APIRoute.Auth.register,
            body: body,
            requiresAuth: false
        )

        guard let idString = response.resolvedID, let id = UUID(uuidString: idString) else {
            throw APIError.decodingFailed(detail: "Supabase signup response had no valid user id.")
        }
        // Echo back the username — signup's response may not include it yet.
        return RegisterResponse(id: id, username: request.username)
    }

    func requestPasswordReset(email: String) async throws {
        try await api.post(
            APIRoute.Auth.requestPasswordReset,
            body: SupabaseRecoverRequest(email: email),
            requiresAuth: false
        )
    }

    func resetPassword(token: String, newPassword: String) async throws {
        // Supabase resets via an emailed link's session, not a typed code.
        throw APIError.notSupported(message: "Password reset isn't implemented for Supabase yet.")
    }

    func logout(refreshToken: String?) async throws {
        try await api.send(Endpoint(APIRoute.Auth.logout, method: .post, requiresAuth: true))
    }
}

struct SupabaseTokenRefresher: TokenRefreshing {

    private let api: any APIClient

    init(api: any APIClient) {
        self.api = api
    }

    func refresh(using refreshToken: String) async throws -> AuthTokens {
        let endpoint = Endpoint(
            APIRoute.Auth.refresh,
            method: .post,
            query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: try .json(SupabaseRefreshRequest(refreshToken: refreshToken)),
            requiresAuth: false
        )
        let response: SupabaseAuthResponse = try await api.send(endpoint)
        return response.tokens
    }
}

// MARK: - Wire types

private struct SupabaseLoginRequest: Encodable {
    let email: String
    let password: String
}

private struct SupabaseRefreshRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct SupabaseRecoverRequest: Encodable {
    let email: String
}

private struct SupabaseSignUpRequest: Encodable {
    let email: String
    let password: String
    let data: Metadata

    struct Metadata: Encodable {
        let firstName: String
        let lastName: String
        let username: String
        let dateOfBirth: String

        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case lastName = "last_name"
            case username
            case dateOfBirth = "date_of_birth"
        }
    }
}

// Signup can return the id flat or nested under "user" — handle both.
private struct SupabaseSignUpResponse: Decodable {
    let id: String?
    let user: NestedUser?

    struct NestedUser: Decodable {
        let id: String
    }

    var resolvedID: String? { id ?? user?.id }
}

private struct SupabaseAuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }

    var tokens: AuthTokens {
        AuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(expiresIn)
        )
    }
}
