//
//  ItemReviewsView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// Third screen under Home.
struct ItemReviewsView: View {

    let itemID: UUID

    @Environment(Router<DashboardRoute>.self) private var router

    var body: some View {
        List {
            Text("Reviews for item \(itemID)", comment: "Placeholder line on the item reviews screen")
                .foregroundStyle(.secondary)

            // Clears the whole stack, which lands back on Home.
            Button {
                router.popToRoot()
            } label: {
                Text("Back to Root", comment: "Button that returns to the Home screen at the root of the stack")
            }
        }
        .navigationTitle(Text("Reviews", comment: "Title of the item reviews screen"))
    }
}
