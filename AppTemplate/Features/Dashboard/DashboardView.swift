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

    // The coordinator owns it — a route carries data in but no closure back out.
    @State private var favoriteNote = "Weekend trip"

    var body: some View {
        @Bindable var router = navigator.dashboard

        NavigationStack(path: $router.path) {
            HomeView(viewModel: dependencies.makeHomeViewModel())
                .dashboardChrome(next: DashboardRoute.firstScreen, signOut: signOut)
                .navigationDestination(for: DashboardRoute.self) { route in
                    destination(for: route)
                }
        }
        .environment(navigator.dashboard)
        .appAlert($router.alert)
        .sheet(item: $router.sheet) { route in
            switch route {
            case let .favoriteSheet(note):
                FavoriteSheetView(note: note) { favoriteNote = $0 }
            default:
                EmptyView()
            }
        }
        .fullScreenCover(item: $router.cover) { route in
            switch route {
            case .favoriteCover:
                FavoriteCoverView()
            default:
                EmptyView()
            }
        }
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
    private func destination(for route: DashboardRoute) -> some View {
        switch route {
        case .favorites, .profile, .settings:
            mainScreen(route)

        case .itemDetail, .itemReviews, .favoriteDetail, .favoriteNotes,
             .editProfile, .changePassword, .notifications, .blockedUsers:
            detailScreen(route)

        // Presented rather than pushed, so they never appear as a destination.
        case .favoriteSheet, .favoriteCover:
            EmptyView()
        }
    }

    // The screens in the chain, which are the only ones carrying the chain's buttons.
    @ViewBuilder
    private func mainScreen(_ route: DashboardRoute) -> some View {
        Group {
            switch route {
            case .favorites:
                FavoritesView(note: $favoriteNote)

            case .profile:
                ProfileView(viewModel: dependencies.makeProfileViewModel())

            case .settings:
                SettingsView()

            default:
                EmptyView()
            }
        }
        .dashboardChrome(next: route.next, signOut: signOut)
    }

    @ViewBuilder
    private func detailScreen(_ route: DashboardRoute) -> some View {
        switch route {
        case let .itemDetail(id):
            ItemDetailView(viewModel: dependencies.makeItemDetailViewModel(id: id))

        case let .itemReviews(id):
            ItemReviewsView(itemID: id)

        case .favoriteDetail:
            FavoriteDetailView()

        case .favoriteNotes:
            FavoriteNotesView()

        case .editProfile:
            EditProfileView()

        case .changePassword:
            ChangePasswordView()

        case .notifications:
            NotificationsView()

        case .blockedUsers:
            BlockedUsersView()

        default:
            EmptyView()
        }
    }
}
