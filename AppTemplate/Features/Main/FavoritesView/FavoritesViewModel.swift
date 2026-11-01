//
//  FavoritesViewModel.swift
//  AppTemplate
//

import Observation

@Observable
@MainActor
final class FavoritesViewModel {

    @ObservationIgnored private let signOutAction: SignOutAction

    init(signOut: SignOutAction) {
        self.signOutAction = signOut
    }

    func signOut() async {
        await signOutAction()
    }
}
