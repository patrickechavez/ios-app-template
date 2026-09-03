//
//  HomeCoverView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct HomeCoverView: View {
    @State private var viewModel: HomeCoverViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: HomeCoverViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text(viewModel.title).font(.title.bold())
                Text(viewModel.subtitle)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle(Text("Full-Screen Cover", comment: "Title of the example full-screen cover"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close", comment: "Button that dismisses the example full-screen cover")
                    }
                }
            }
        }
    }
}
