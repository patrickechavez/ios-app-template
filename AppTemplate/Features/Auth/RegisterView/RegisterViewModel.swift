//
//  RegisterViewModel.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class RegisterViewModel {

    var firstName = ""
    var lastName = ""
    var email = ""
    var username = ""
    var dateOfBirth: Date?
    var phoneCountry: Country?
    var phoneNumber = ""
    var password = ""

    let action = ActionState()

    private(set) var didRegister = false

    @ObservationIgnored private let auth: any AuthRepository

    private static let minimumPasswordLength = 8

    // Fixed format because the server expects a calendar date, not a localised one.
    private static let dateOfBirthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    init(auth: any AuthRepository) {
        self.auth = auth
    }

    // Nothing later than today can be picked, so the field only has to cap the earliest date.
    var dateOfBirthRange: ClosedRange<Date> { Date.distantPast...Date() }

    var firstNameError: String? { action.message(for: "firstName") }
    var lastNameError: String? { action.message(for: "lastName") }
    var usernameError: String? { action.message(for: "username") }

    var emailError: String? {
        action.message(for: "email") { InputValidation.email(email) }
    }

    var passwordError: String? {
        if let serverMessage = action.message(for: "password") { return serverMessage }
        guard !password.isEmpty, password.count < Self.minimumPasswordLength else { return nil }
        return String(
            localized: "Use at least \(Self.minimumPasswordLength) characters.",
            comment: "Validation message shown when a password is too short"
        )
    }

    var dateOfBirthError: String? { action.message(for: "dateOfBirth") }

    var phoneError: String? { action.message(for: "phone") }

    // Optional — nil unless a number was actually typed. E.164 for the wire.
    private var phone: String? {
        guard let phoneCountry, phoneNumber.contains(where: \.isNumber) else { return nil }
        return phoneCountry.e164(nationalNumber: phoneNumber)
    }

    var canSubmit: Bool {
        !action.isRunning
            && !firstName.trimmed.isEmpty
            && !lastName.trimmed.isEmpty
            && !username.trimmed.isEmpty
            && email.trimmed.isValidEmail
            && dateOfBirth != nil
            && password.count >= Self.minimumPasswordLength
    }

    func submit() async {
        guard canSubmit, let dateOfBirth else { return }

        let request = RegisterRequest(
            firstName: firstName.trimmed,
            lastName: lastName.trimmed,
            email: email.trimmed,
            username: username.trimmed,
            dateOfBirth: Self.dateOfBirthFormatter.string(from: dateOfBirth),
            phone: phone,
            password: password
        )

        let response = await action.run { [auth] in
            try await auth.register(request)
        }
        guard response != nil else { return }

        password = ""
        didRegister = true
    }
}
