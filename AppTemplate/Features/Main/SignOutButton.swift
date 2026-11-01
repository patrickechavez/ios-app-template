//
//  SignOutButton.swift
//  AppTemplate
//

import SwiftUI

// Sits at the bottom of every main screen. Confirms first, since one stray tap would end the session.
struct SignOutButton: View {

    let signOut: () async -> Void

    @Environment(Router<MainRoute>.self) private var router

    var body: some View {
        Button(role: .destructive) {
            router.present(alert: .confirmDestructive(
                String(
                    localized: "Sign out of your account?",
                    comment: "Title of the sign-out confirmation alert"
                ),
                message: String(
                    localized: "You'll need to sign in again to use the app.",
                    comment: "Message of the sign-out confirmation alert"
                ),
                confirm: String(localized: "Sign Out", comment: "Confirm button of the sign-out alert"),
                onConfirm: {
                    Task { await signOut() }
                }
            ))
        } label: {
            Text("Sign Out", comment: "Button that signs the user out")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding(Theme.Spacing.lg)
        .background(.bar)
    }
}
