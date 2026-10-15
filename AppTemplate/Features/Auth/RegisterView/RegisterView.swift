//
//  RegisterView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct RegisterView: View {

    @State private var viewModel: RegisterViewModel
    @Environment(Router<AuthRoute>.self) private var router
    @Environment(\.dismiss) private var dismiss

    init(viewModel: RegisterViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                AppTextField(
                    text: $viewModel.firstName,
                    placeholder: String(localized: "First name", comment: "Placeholder for the first name field"),
                    label: String(localized: "First name", comment: "Label for the first name field"),
                    error: viewModel.firstNameError,
                    capitalization: .words,
                    contentType: .givenName
                )

                AppTextField(
                    text: $viewModel.lastName,
                    placeholder: String(localized: "Last name", comment: "Placeholder for the last name field"),
                    label: String(localized: "Last name", comment: "Label for the last name field"),
                    error: viewModel.lastNameError,
                    capitalization: .words,
                    contentType: .familyName
                )

                EmailField(
                    text: $viewModel.email,
                    error: viewModel.emailError
                )

                UsernameField(
                    text: $viewModel.username,
                    error: viewModel.usernameError
                )

                DateField(
                    label: String(localized: "Date of birth", comment: "Label for the date of birth field"),
                    date: $viewModel.dateOfBirth,
                    error: viewModel.dateOfBirthError,
                    range: viewModel.dateOfBirthRange
                )

                PhoneField(
                    country: $viewModel.phoneCountry,
                    nationalNumber: $viewModel.phoneNumber,
                    error: viewModel.phoneError
                )

                PasswordField(
                    text: $viewModel.password,
                    error: viewModel.passwordError,
                    isNewPassword: true
                )

                if let error = viewModel.generalError {
                    InlineErrorText(error)
                }

                AsyncButton(
                    title: Text("Create Account", comment: "Primary button on the registration screen"),
                    isRunning: viewModel.action.isRunning,
                    action: { await viewModel.submit() }
                )
                .disabled(!viewModel.canSubmit)
            }
            .padding(Theme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(Text("Create Account", comment: "Title of the registration screen"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.didRegister) { _, didRegister in
            guard didRegister else { return }
            router.present(alert: AlertState(
                title: String(localized: "Account created", comment: "Title of the registration success alert"),
                message: String(
                    localized: "You can now sign in with your new account.",
                    comment: "Message of the registration success alert"
                ),
                buttons: [AlertButton(title: String(localized: "OK", comment: "Alert dismiss button")) {
                    dismiss()
                }]
            ))
        }
    }
}

#if DEBUG

#Preview {
    PreviewHost { dependencies in
        NavigationStack {
            RegisterView(viewModel: dependencies.makeRegisterViewModel())
        }
        .environment(Router<AuthRoute>())
    }
}

#endif
