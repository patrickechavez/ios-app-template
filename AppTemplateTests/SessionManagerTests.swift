//
//  SessionManagerTests.swift
//  AppTemplateTests
//

import Testing
@testable import AppTemplate

@MainActor
struct SessionManagerTests {

    private func makeSession(
        tokens: AuthTokens? = nil,
        users: MockUserRepository = MockUserRepository(),
        onboarding: InMemoryOnboardingStore = InMemoryOnboardingStore()
    ) async -> SessionManager {
        let tokenStore = InMemoryTokenStore()
        if let tokens {
            try? await tokenStore.save(tokens)
        }
        return SessionManager(tokenStore: tokenStore, users: users, onboarding: onboarding)
    }

    // MARK: - First run

    @Test func aFreshInstallWithoutATokenShowsOnboardingFirst() async {
        let session = await makeSession()

        await session.bootstrap()

        #expect(session.state == .onboarding)
    }

    @Test func finishingOnboardingOnAFreshInstallLandsOnSignIn() async {
        let session = await makeSession()
        await session.bootstrap()

        session.completeOnboarding()

        #expect(session.state == .unauthenticated)
    }

    // The Keychain outlives an uninstall, so a reinstall can restore a session. That user has
    // still never seen onboarding, and should see it once before reaching the dashboard.
    @Test func aRestoredSessionStillSeesOnboardingOnce() async {
        let session = await makeSession(tokens: AuthTokens(accessToken: "abc123"))

        await session.bootstrap()

        #expect(session.state == .onboarding)
    }

    @Test func finishingOnboardingWithARestoredSessionLandsOnTheDashboard() async {
        let session = await makeSession(tokens: AuthTokens(accessToken: "abc123"))
        await session.bootstrap()

        session.completeOnboarding()

        #expect(session.state == .authenticated)
    }

    @Test func completingOnboardingMarksItSeen() async {
        let onboarding = InMemoryOnboardingStore()
        let session = await makeSession(onboarding: onboarding)
        await session.bootstrap()

        session.completeOnboarding()

        #expect(onboarding.hasSeen)
    }

    // MARK: - Once it has been seen

    @Test func anInstallThatHasSeenOnboardingGoesStraightToSignIn() async {
        let session = await makeSession(onboarding: InMemoryOnboardingStore(hasSeen: true))

        await session.bootstrap()

        #expect(session.state == .unauthenticated)
    }

    @Test func anInstallThatHasSeenOnboardingGoesStraightToTheDashboard() async {
        let session = await makeSession(
            tokens: AuthTokens(accessToken: "abc123"),
            onboarding: InMemoryOnboardingStore(hasSeen: true)
        )

        await session.bootstrap()

        #expect(session.state == .authenticated)
    }

    // A rejected token must sign out rather than wait behind onboarding.
    @Test func aRejectedTokenSignsOutEvenOnAFirstRun() async {
        let users = MockUserRepository()
        users.currentUserResult = .failure(APIError.unauthorized())
        let session = await makeSession(tokens: AuthTokens(accessToken: "stale"), users: users)

        await session.bootstrap()

        #expect(session.state == .unauthenticated)
    }
}
