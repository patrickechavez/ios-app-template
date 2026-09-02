//
//  ActionState.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

@Observable
@MainActor
final class ActionState {

    private(set) var isRunning = false
    private(set) var error: APIError?

    var fieldErrors: [String: [String]] {
        error?.validationErrors?.fields ?? [:]
    }

    var errorMessage: String? {
        error?.localizedDescription
    }

    func message(for field: String) -> String? {
        error?.validationErrors?.first(for: field)
    }

    func clear() {
        error = nil
    }

    @discardableResult
    func run<T>(_ operation: @Sendable () async throws -> T) async -> T? {
        guard !isRunning else { return nil }

        error = nil
        isRunning = true
        defer { isRunning = false }

        do {
            return try await operation()
        } catch {
            let apiError = error as? APIError ?? APIError.from(transportError: error)

            if apiError.isWorthReporting { Observability.crashes.record(apiError) }

            guard apiError.isUserFacing else { return nil }
            self.error = apiError
            return nil
        }
    }
}
