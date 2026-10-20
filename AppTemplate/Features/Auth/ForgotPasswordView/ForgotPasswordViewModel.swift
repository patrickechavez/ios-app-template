//
//  ForgotPasswordViewModel.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class ForgotPasswordViewModel {

    var email = ""
    let action = ActionState()

    private(set) var didSend = false

    @ObservationIgnored private let auth: any AuthRepository

    init(auth: any AuthRepository) {
        self.auth = auth
    }

    var canSubmit: Bool {
        email.trimmed.isValidEmail && !action.isRunning
    }

    var emailError: String? {
        action.message(for: "email") { InputValidation.email(email) }
    }

    var confirmation: String {
        String(
            localized: "If an account exists for that address, we've sent a link to reset your password.",
            comment: "Confirmation shown after requesting a password reset"
        )
    }

    func submit() async {
        guard canSubmit else { return }

        let address = email.trimmed
        let result: Void? = await action.run { [auth] in
            try await auth.requestPasswordReset(email: address)
        }
        guard result != nil else { return }

        didSend = true
    }
}
