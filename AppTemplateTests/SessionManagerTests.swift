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

    // MARK: - A session ending while onboarding is on screen

    // The hole this closes: `expire()` guarded on `state == .authenticated`, which is false while
    // the real outcome is parked behind onboarding, so the token was cleared and the user was then
    // promoted to a dashboard they had no session for.
    @Test func expiringDuringOnboardingLandsOnSignInRatherThanAnEmptyDashboard() async {
        let session = await makeSession(tokens: AuthTokens(accessToken: "abc123"))
        await session.bootstrap()
        #expect(session.state == .onboarding)

        await session.expire()
        session.completeOnboarding()

        #expect(session.state == .unauthenticated)
    }

    // Losing a session in the background is not a reason to throw someone out of a screen they
    // are part way through reading.
    @Test func expiringDuringOnboardingDoesNotInterruptTheReader() async {
        let session = await makeSession(tokens: AuthTokens(accessToken: "abc123"))
        await session.bootstrap()

        await session.expire()

        #expect(session.state == .onboarding)
    }

    @Test func signingOutDuringOnboardingStillMarksItSeen() async {
        let onboarding = InMemoryOnboardingStore()
        let session = await makeSession(
            tokens: AuthTokens(accessToken: "abc123"),
            onboarding: onboarding
        )
        await session.bootstrap()

        await session.signOut()
        session.completeOnboarding()

        #expect(onboarding.hasSeen)
        #expect(session.state == .unauthenticated)
    }

    // The guard still has to refuse when there is no session to lose, or every launch without a
    // token would log an expiry it never had.
    @Test func expiringWithNoSessionToLoseDoesNothing() async {
        let session = await makeSession()
        await session.bootstrap()

        await session.expire()
        session.completeOnboarding()

        #expect(session.state == .unauthenticated)
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
