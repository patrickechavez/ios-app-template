//
//  SearchField.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

// Standalone search box with a magnifier and a clear button.
// For a search bar attached to a navigation bar, use SwiftUI's .searchable instead.
struct SearchField: View {

    @Binding var text: String

    var placeholder: String = String(localized: "Search", comment: "Placeholder for a search field")
    var identifier: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Color.secondaryText)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier(identifier ?? "")

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Color.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search", comment: "Accessibility label for the clear-search button"))
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 2)
        .background(Theme.Color.secondaryBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}
