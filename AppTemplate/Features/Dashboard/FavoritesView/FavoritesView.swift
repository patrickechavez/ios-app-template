//
//  FavoritesView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// First screen of the Favorites tab.
struct FavoritesView: View {

    @Environment(Router<FavoritesRoute>.self) private var router

    var body: some View {
        List {
            Button {
                router.push(.favoriteDetail)
            } label: {
                Label {
                    Text("Open a favorite", comment: "Row that opens the favorite detail screen")
                } icon: {
                    Image(systemName: "heart")
                }
            }
        }
        .navigationTitle(Text("Favorites", comment: "Title of the favorites screen"))
    }
}
