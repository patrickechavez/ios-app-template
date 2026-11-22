//
//  LoginViewModel.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class LoginViewModel {

    var email = ""
    var password = ""

    let action = ActionState()

    @ObservationIgnored private let auth: any AuthRepository
    @ObservationIgnored private let session: SessionManager

    init(auth: any AuthRepository, session: SessionManager) {
        self.auth = auth
        self.session = session
    }

    var canSubmit: Bool {
        !email.trimmed.isEmpty && !password.isEmpty && !action.isRunning
    }

    var emailError: String? { action.message(for: "email") }
    var passwordError: String? { action.message(for: "password") }

    func signIn() async {
        guard canSubmit else { return }

        let credentials = (email: email.trimmed, password: password)
        let tokens = await action.run { [auth] in
            try await auth.login(username: credentials.email, password: credentials.password)
        }

        // The failure is already on `action.error`, and APIError.classify logged it.
        guard let tokens else { return }

        password = ""
        await session.didAuthenticate(tokens: tokens)
    }
}
