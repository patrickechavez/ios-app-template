//
//  FavoriteDetailView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// Second screen of the Favorites tab.
struct FavoriteDetailView: View {

    @Environment(Router<FavoritesRoute>.self) private var router

    var body: some View {
        List {
            Button {
                router.push(.favoriteNotes)
            } label: {
                Text("Next", comment: "Button that opens the next screen")
            }

            // The arrow in the navigation bar already does this. Use the code
            // version when you need to leave after doing something, like saving.
            Button {
                router.pop()
            } label: {
                Text("Back", comment: "Button that returns to the previous screen")
            }
        }
        .navigationTitle(Text("Favorite", comment: "Title of the favorite detail screen"))
    }
}
