//
//  RouterTests.swift
//  AppTemplateTests
//

import Foundation
import Testing
@testable import AppTemplate

@MainActor
struct RouterTests {

    @Test func presentsAndDismissesASheet() {
        let router = Router<AuthRoute>()

        router.present(sheet: .resetPassword(token: "abc123"))
        #expect(router.sheet == .resetPassword(token: "abc123"))

        router.dismissSheet()
        #expect(router.sheet == nil)
    }

    @Test func presentsAndDismissesACover() {
        let router = Router<AuthRoute>()

        router.present(cover: .register)
        #expect(router.cover == .register)

        router.dismissCover()
        #expect(router.cover == nil)
    }

    @Test func keepsSheetAndCoverIndependent() {
        let router = Router<AuthRoute>()

        router.present(sheet: .resetPassword(token: "abc123"))
        router.present(cover: .register)
        router.dismissSheet()

        #expect(router.sheet == nil)
        #expect(router.cover == .register)
    }

    @Test func leavesModalsOutOfRestoration() {
        let router = Router<AuthRoute>()
        router.push(.forgotPassword)
        router.present(sheet: .resetPassword(token: "abc123"))
        router.present(cover: .register)

        let restored = Router<AuthRoute>()
        restored.restore(from: router.restorationData)

        #expect(restored.path == [.forgotPassword])
        #expect(restored.sheet == nil)
        #expect(restored.cover == nil)
    }

    @Test func doesNotPresentAModalWhenPushing() {
        let router = Router<AuthRoute>()

        router.push(.forgotPassword)

        #expect(router.sheet == nil)
        #expect(router.cover == nil)
    }
}
