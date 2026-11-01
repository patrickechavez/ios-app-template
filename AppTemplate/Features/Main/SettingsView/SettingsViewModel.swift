//
//  SettingsViewModel.swift
//  AppTemplate
//

import Observation

@Observable
@MainActor
final class SettingsViewModel {

    @ObservationIgnored private let signOutAction: SignOutAction

    init(signOut: SignOutAction) {
        self.signOutAction = signOut
    }

    func signOut() async {
        await signOutAction()
    }
}
