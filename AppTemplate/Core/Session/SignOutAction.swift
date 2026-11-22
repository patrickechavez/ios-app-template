//
//  SignOutAction.swift
//  AppTemplate
//

import Foundation
import os

// Signing out from anywhere: tells the server first, then clears the phone either way.
@MainActor
struct SignOutAction {

    private let auth: any AuthRepository
    private let session: SessionManager
    private let tokenStore: any TokenStore

    init(auth: any AuthRepository, session: SessionManager, tokenStore: any TokenStore) {
        self.auth = auth
        self.session = session
        self.tokenStore = tokenStore
    }

    func callAsFunction() async {
        let refreshToken = await tokenStore.load()?.refreshToken

        do {
            try await auth.logout(refreshToken: refreshToken)
        } catch {
            AppLogger.auth.notice(
                """
                Server-side logout failed \
                (\(error.localizedDescription, privacy: .public)); clearing locally anyway.
                """
            )
        }

        await session.signOut()
    }
}
