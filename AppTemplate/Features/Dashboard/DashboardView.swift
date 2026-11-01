//
//  DashboardView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

// One stack rooted at Home. The Next button walks Home to Favorites to Profile to Settings.
struct DashboardView: View {

    let dependencies: AppDependencies

    @Environment(AppNavigator.self) private var navigator

    @SceneStorage("dashboard.path") private var storedPath: Data?

    var body: some View {
        @Bindable var router = navigator.dashboard

        NavigationStack(path: $router.path) {
            HomeView(viewModel: dependencies.makeHomeViewModel())
                .dashboardChrome(next: DashboardRoute.firstScreen, signOut: signOut)
                .navigationDestination(for: DashboardRoute.self) { route in
                    screen(route)
                }
        }
        .environment(navigator.dashboard)
        .appAlert($router.alert)
        .task {
            navigator.dashboard.restore(from: storedPath)
        }
        .onChange(of: navigator.dashboard.path) { _, _ in
            storedPath = navigator.dashboard.restorationData
        }
    }

    private var signOut: SignOutAction {
        dependencies.makeSignOutAction()
    }

    @ViewBuilder
    private func screen(_ route: DashboardRoute) -> some View {
        Group {
            switch route {
            case .favorites:
                FavoritesView()

            case .profile:
                ProfileView(viewModel: dependencies.makeProfileViewModel())

            case .settings:
                SettingsView()
            }
        }
        .dashboardChrome(next: route.next, signOut: signOut)
    }
}
