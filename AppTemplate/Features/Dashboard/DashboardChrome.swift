//
//  DashboardChrome.swift
//  AppTemplate
//

import SwiftUI

// The buttons every main screen carries: log out, go to the next screen, and jump back to Home.
private struct DashboardChrome: ViewModifier {

    let next: DashboardRoute?

    let signOut: SignOutAction

    @Environment(Router<DashboardRoute>.self) private var router

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    Task { await signOut() }
                } label: {
                    Text("Sign Out", comment: "Button that signs the user out")
                }
            }

            // Home is the root, so it has nowhere to jump back to.
            if !router.isAtRoot {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.popToRoot()
                    } label: {
                        Image(systemName: "house")
                    }
                    .accessibilityLabel(Text("Home", comment: "Button that returns to the Home screen"))
                }
            }

            if let next {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.push(next)
                    } label: {
                        Text("Next", comment: "Button that opens the next screen")
                    }
                }
            }
        }
    }
}

extension View {

    // Applied to the four main screens only; the detail screens behind them keep their own Back button.
    func dashboardChrome(next: DashboardRoute?, signOut: SignOutAction) -> some View {
        modifier(DashboardChrome(next: next, signOut: signOut))
    }
}
