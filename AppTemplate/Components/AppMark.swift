//
//  AppMark.swift
//  AppTemplate
//

import SwiftUI

// Placeholder for the app's own mark at the top of a sign-in screen. A project copying this
// template replaces the symbol, or the whole body, with its own artwork in this one place.
struct AppMark: View {

    var size: CGFloat = 72

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.224, style: .continuous)
            .fill(Theme.Color.secondaryBackground)
            .overlay {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(Theme.Color.accent)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
