//
//  NotificationsView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// Second screen of the Settings tab.
struct NotificationsView: View {

    @Environment(Router<SettingsRoute>.self) private var router

    var body: some View {
        List {
            Button {
                router.push(.blockedUsers)
            } label: {
                Text("Blocked Users", comment: "Button that opens the blocked users screen")
            }

            // The arrow in the navigation bar already does this. Use the code
            // version when you need to leave after doing something, like saving.
            Button {
                router.pop()
            } label: {
                Text("Back", comment: "Button that returns to the previous screen")
            }
        }
        .navigationTitle(Text("Notifications", comment: "Title of the notification settings screen"))
    }
}
