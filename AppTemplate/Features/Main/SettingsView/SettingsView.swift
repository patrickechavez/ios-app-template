//
//  SettingsView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// Main screen reached from Profile. Empty until the app has settings to show.
struct SettingsView: View {

    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        List {
        }
        .navigationTitle(Text("Settings", comment: "Title of the settings screen"))
        .safeAreaInset(edge: .bottom) {
            SignOutButton(signOut: viewModel.signOut)
        }
    }
}

#if DEBUG

#Preview {
    PreviewHost { dependencies in
        NavigationStack {
            SettingsView(viewModel: dependencies.makeSettingsViewModel())
        }
        .environment(Router<MainRoute>())
    }
}

#endif
