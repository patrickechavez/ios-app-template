//
//  MainFlowView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

// One stack rooted at Home. The Next button walks Home to Favorites to Profile to Settings.
struct MainFlowView: View {

    let dependencies: AppDependencies

    @Environment(AppNavigator.self) private var navigator

    @SceneStorage("main.path") private var storedPath: Data?

    var body: some View {
        @Bindable var router = navigator.main

        NavigationStack(path: $router.path) {
            HomeView(viewModel: dependencies.makeHomeViewModel())
                .mainFlowChrome(next: MainRoute.firstScreen)
                .navigationDestination(for: MainRoute.self) { route in
                    screen(route)
                }
        }
        .environment(navigator.main)
        .appAlert($router.alert)
        .task {
            navigator.main.restore(from: storedPath)
        }
        .onChange(of: navigator.main.path) { _, _ in
            storedPath = navigator.main.restorationData
        }
    }

    @ViewBuilder
    private func screen(_ route: MainRoute) -> some View {
        Group {
            switch route {
            case .favorites:
                FavoritesView(viewModel: dependencies.makeFavoritesViewModel())

            case .profile:
                ProfileView(viewModel: dependencies.makeProfileViewModel())

            case .settings:
                SettingsView(viewModel: dependencies.makeSettingsViewModel())
            }
        }
        .mainFlowChrome(next: route.next)
    }
}
