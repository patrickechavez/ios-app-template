//
//  OnboardingPage.swift
//  AppTemplate
//

import Foundation

// One screen of the first-run flow. Copy lives here rather than in the view so a project copying
// this template changes what the pages say without touching layout.
struct OnboardingPage: Identifiable, Equatable, Sendable {

    let id: Int
    let symbol: String
    let title: String
    let message: String
}

extension OnboardingPage {

    // Placeholder copy. A project built on this template is expected to replace all three.
    static let defaults: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            symbol: "sparkles",
            title: String(
                localized: "Welcome",
                comment: "Title of the first onboarding page"
            ),
            message: String(
                localized: "A short line about what this app is for.",
                comment: "Body of the first onboarding page"
            )
        ),
        OnboardingPage(
            id: 1,
            symbol: "square.grid.2x2",
            title: String(
                localized: "Everything in one place",
                comment: "Title of the second onboarding page"
            ),
            message: String(
                localized: "A short line about the feature that matters most.",
                comment: "Body of the second onboarding page"
            )
        ),
        OnboardingPage(
            id: 2,
            symbol: "checkmark.circle",
            title: String(
                localized: "Ready when you are",
                comment: "Title of the last onboarding page"
            ),
            message: String(
                localized: "A short line inviting the reader to begin.",
                comment: "Body of the last onboarding page"
            )
        )
    ]
}
