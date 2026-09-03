//
//  ActionState.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

/// Runs a single user action — sign in, save, upload — and turns whatever is
/// thrown into something the form can show. For one-shot buttons; use
/// `LoadState` for screens that load content.
///
///     let user = await action.run { [repository] in
///         try await repository.uploadAvatar(image)
///     }
@Observable
@MainActor
final class ActionState {

    /// True while the action is in flight.
    private(set) var isRunning = false

    /// The last failure, reset on every new attempt.
    private(set) var error: APIError?

    /// Server-side validation errors, keyed by field name.
    var fieldErrors: [String: [String]] {
        error?.validationErrors?.fields ?? [:]
    }

    /// One message describing the last failure.
    var errorMessage: String? {
        error?.localizedDescription
    }

    /// The message for one field, when the server flagged it.
    func message(for field: String) -> String? {
        error?.validationErrors?.first(for: field)
    }

    func clear() {
        error = nil
    }

    /// Runs `operation`. Returns nil when one is already running or it
    /// failed — check `error` and `fieldErrors` to tell the user why.
    @discardableResult
    func run<T>(_ operation: @Sendable () async throws -> T) async -> T? {
        guard !isRunning else { return nil }

        error = nil
        isRunning = true
        defer { isRunning = false }

        do {
            return try await operation()
        } catch {
            let apiError = APIError.classify(error)

            // A cancelled attempt is not an error worth showing.
            guard apiError.isUserFacing else { return nil }
            self.error = apiError
            return nil
        }
    }
}
