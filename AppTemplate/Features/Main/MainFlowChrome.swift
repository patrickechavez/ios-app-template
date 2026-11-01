//
//  MainFlowChrome.swift
//  AppTemplate
//

import SwiftUI

// The toolbar buttons that move through the chain. Signing out is a button on each screen instead.
private struct MainFlowChrome: ViewModifier {

    let next: MainRoute?

    @Environment(Router<MainRoute>.self) private var router

    func body(content: Content) -> some View {
        content.toolbar {
            // Home is the root, so it has nowhere to jump back to.
            if !router.isAtRoot {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.popToRoot()
                    } label: {
                        Image(systemName: "house")
                    }
                    .accessibilityLabel(Text("Home", comment: "Button that returns to the Home screen"))
                }
            }

            if let next {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.push(next)
                    } label: {
                        Text("Next", comment: "Button that opens the next screen")
                    }
                }
            }
        }
    }
}

extension View {

    func mainFlowChrome(next: MainRoute?) -> some View {
        modifier(MainFlowChrome(next: next))
    }
}
