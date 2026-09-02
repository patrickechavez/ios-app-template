//
//  FavoritesTab.swift
//  AppTemplate
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

struct FavoritesTab: View {

    @Environment(AppNavigator.self) private var navigator

    var body: some View {
        @Bindable var router = navigator.favorites

        NavigationStack(path: $router.path) {
            FavoritesView()
                .navigationDestination(for: FavoritesRoute.self) { route in
                    switch route {
                    case .favoriteDetail:
                        FavoriteDetailView()
                    case .favoriteNotes:
                        FavoriteNotesView()
                    }
                }
        }
        .environment(navigator.favorites)
        .appAlert($router.alert)
    }
}
