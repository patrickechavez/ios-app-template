//
//  SupabaseAuthRepository.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

// Speaks Supabase's Auth API (GoTrue) instead of a generic REST backend.
// Kept separate from AuthRepository.swift so every Supabase-specific detail —
// wire shapes, snake_case keys, the login/refresh query params — lives in
// one file that's easy to find and to delete later.
nonisolated struct SupabaseAuthRepository: AuthRepository {

    private let api: any APIClient

    init(api: any APIClient) {
        self.api = api
    }

    func login(username: String, password: String) async throws -> AuthTokens {
        // Supabase authenticates by email, not username — the protocol's
        // parameter name is unchanged so other backends are unaffected;
        // this is the one place that treats the value as an email.
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

        guard let id = response.resolvedID else {
            throw APIError.decodingFailed(detail: "Supabase signup response had no user id.")
        }
        // Echo back what was submitted — Supabase's own response doesn't
        // reliably reflect user_metadata immediately after signup.
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
        // Supabase resets a password by redeeming the session from its
        // emailed recovery link, not a typed code — this needs its own
        // deep-link design, so it's deliberately unsupported for now.
        throw APIError.notSupported(message: "Password reset isn't implemented for Supabase yet.")
    }

    func logout(refreshToken: String?) async throws {
        // No body — the Bearer access token identifies which session to end.
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

// Top-level `private` is file-scoped in Swift, so both types above can use these.

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

// Handles both response shapes Supabase can return from /signup: a flat
// user object, or one nested under "user" when a session comes back too.
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
