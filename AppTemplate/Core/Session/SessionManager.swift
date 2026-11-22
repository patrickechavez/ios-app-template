//
//  SessionManager.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation
import Observation
import os

@Observable
@MainActor
final class SessionManager {

    enum State: Equatable {

        case bootstrapping
        case onboarding
        case unauthenticated
        case authenticated
    }

    private(set) var state: State = .bootstrapping

    private(set) var currentUser: User?

    private(set) var serviceStatus: ServiceStatus?

    enum ServiceStatus: Equatable {
        case updateRequired(message: String?)
        case maintenance(message: String?)
    }

    @ObservationIgnored private let tokenStore: any TokenStore
    @ObservationIgnored private let users: any UserRepository
    @ObservationIgnored private let onboarding: any OnboardingStoring

    // Where bootstrap landed, held back while onboarding is on screen.
    @ObservationIgnored private var stateAfterOnboarding: State?

    init(
        tokenStore: any TokenStore,
        users: any UserRepository,
        onboarding: any OnboardingStoring = UserDefaultsOnboardingStore()
    ) {
        self.tokenStore = tokenStore
        self.users = users
        self.onboarding = onboarding
    }

    func bootstrap() async {
        guard await tokenStore.load() != nil else {
            resolve(to: .unauthenticated)
            return
        }

        do {
            currentUser = try await users.currentUser()
            resolve(to: .authenticated)
            AppLogger.lifecycle.notice("Resumed existing session")
        } catch let error as APIError where error.invalidatesSession {

            await signOut()
        } catch {

            AppLogger.lifecycle.notice(
                """
                Could not verify session \
                (\(error.localizedDescription, privacy: .public)); continuing optimistically.
                """
            )
            resolve(to: .authenticated)
        }
    }

    // Onboarding wraps the outcome rather than replacing it, so a reinstall that restored a
    // Keychain session still shows the flow once before landing on the signed-in app.
    private func resolve(to outcome: State) {
        guard !onboarding.hasSeen else {
            state = outcome
            return
        }

        stateAfterOnboarding = outcome
        state = .onboarding
    }

    func completeOnboarding() {
        onboarding.markSeen()
        state = stateAfterOnboarding ?? .unauthenticated
        stateAfterOnboarding = nil
    }

    func didAuthenticate(tokens: AuthTokens, user: User? = nil) async {
        do {
            try await tokenStore.save(tokens)
        } catch {

            AppLogger.auth.error("Could not persist tokens: \(error.localizedDescription, privacy: .public)")
        }

        currentUser = user
        state = .authenticated

        if user == nil {

            Task { await refreshCurrentUser() }
        }
    }

    func signOut() async {
        await tokenStore.clear()
        currentUser = nil

        // A reader part way through onboarding is not interrupted by a session ending behind
        // them. Only where they land when they finish changes.
        if state == .onboarding {
            stateAfterOnboarding = .unauthenticated
        } else {
            state = .unauthenticated
        }

        AppLogger.lifecycle.notice("Signed out")
    }

    func refreshCurrentUser() async {
        guard state == .authenticated else { return }
        currentUser = try? await users.currentUser()
    }

    func update(user: User) {
        currentUser = user
    }

    func dismissServiceStatus() {
        serviceStatus = nil
    }

    /// Called when tokens can't be refreshed; ends the session if it hasn't ended.
    func expire() async {
        guard hasSession else { return }
        AppLogger.auth.notice("Session expired, returning to sign-in")
        await signOut()
    }

    // A session can be held back behind onboarding, where `state` reports `.onboarding` rather
    // than `.authenticated`. Comparing against `state` alone would miss it, and the compiler
    // cannot catch that the way it catches a missing `switch` case.
    private var hasSession: Bool {
        state == .authenticated || stateAfterOnboarding == .authenticated
    }

    /// Called when the backend says the app is too old or down for maintenance.
    func show(serviceStatus: ServiceStatus) {
        self.serviceStatus = serviceStatus
    }
}
