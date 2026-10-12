//
//  OnboardingStore.swift
//  AppTemplate
//

import Foundation

// Whether the first-run flow has already been shown on this device.
//
// Deliberately not the Keychain, which survives uninstall: a reinstall should feel like a fresh
// start, so this lives in UserDefaults and goes away with the app.
protocol OnboardingStoring: Sendable {

    var hasSeen: Bool { get }

    func markSeen()
}

// UserDefaults is documented as thread-safe, which the compiler has no way to see, so the
// conformance is unchecked rather than the type working around a guarantee it already has.
struct UserDefaultsOnboardingStore: OnboardingStoring, @unchecked Sendable {

    private let defaults: UserDefaults
    private let key: String

    // The key is a parameter so a test can use its own and never read a value a real run left.
    init(defaults: UserDefaults = .standard, key: String = "onboarding.hasSeen") {
        self.defaults = defaults
        self.key = key
    }

    var hasSeen: Bool {
        defaults.bool(forKey: key)
    }

    func markSeen() {
        defaults.set(true, forKey: key)
    }
}

// Mirrors InMemoryTokenStore: a double for tests and previews, with no UserDefaults underneath.
final class InMemoryOnboardingStore: OnboardingStoring, @unchecked Sendable {

    private(set) var hasSeen: Bool

    init(hasSeen: Bool = false) {
        self.hasSeen = hasSeen
    }

    func markSeen() {
        hasSeen = true
    }
}
