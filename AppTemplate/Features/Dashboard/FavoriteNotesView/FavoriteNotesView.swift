//
//  FavoriteNotesView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// Third screen under Favorites.
struct FavoriteNotesView: View {

    @Environment(Router<DashboardRoute>.self) private var router

    var body: some View {
        List {
            // Clears the whole stack, which lands back on Home.
            Button {
                router.popToRoot()
            } label: {
                Text("Back to Root", comment: "Button that returns to the Home screen at the root of the stack")
            }
        }
        .navigationTitle(Text("Notes", comment: "Title of the favorite notes screen"))
    }
}
