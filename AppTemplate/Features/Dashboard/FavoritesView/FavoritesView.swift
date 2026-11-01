//
//  FavoritesView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// Main screen reached from Home. Empty until the app has favorites to show.
struct FavoritesView: View {

    var body: some View {
        List {
        }
        .navigationTitle(Text("Favorites", comment: "Title of the favorites screen"))
    }
}

#if DEBUG

#Preview {
    NavigationStack {
        FavoritesView()
    }
}

#endif
