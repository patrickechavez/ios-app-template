//
//  HomeSheetView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct HomeSheetView: View {
    @State private var viewModel: HomeSheetViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: HomeSheetViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text(viewModel.title).font(.title2.bold())
                Text(viewModel.subtitle)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle(Text("Sheet", comment: "Title of the example sheet screen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done", comment: "Button that dismisses the example sheet")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
