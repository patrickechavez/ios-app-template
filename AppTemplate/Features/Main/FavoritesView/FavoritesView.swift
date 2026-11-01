//
//  FavoritesView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// Main screen reached from Home. Empty until the app has favorites to show.
struct FavoritesView: View {

    @State private var viewModel: FavoritesViewModel

    init(viewModel: FavoritesViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        List {
        }
        .navigationTitle(Text("Favorites", comment: "Title of the favorites screen"))
        .safeAreaInset(edge: .bottom) {
            SignOutButton(signOut: viewModel.signOut)
        }
    }
}

#if DEBUG

#Preview {
    PreviewHost { dependencies in
        NavigationStack {
            FavoritesView(viewModel: dependencies.makeFavoritesViewModel())
        }
        .environment(Router<MainRoute>())
    }
}

#endif
