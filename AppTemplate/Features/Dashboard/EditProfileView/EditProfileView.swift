//
//  EditProfileView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// Second screen of the Profile tab.
struct EditProfileView: View {

    @Environment(Router<ProfileRoute>.self) private var router

    var body: some View {
        List {
            Button {
                router.push(.changePassword)
            } label: {
                Text("Change Password", comment: "Button that opens the change password screen")
            }

            // The arrow in the navigation bar already does this. Use the code
            // version when you need to leave after doing something, like saving.
            Button {
                router.pop()
            } label: {
                Text("Back", comment: "Button that returns to the previous screen")
            }
        }
        .navigationTitle(Text("Edit Profile", comment: "Title of the edit profile screen"))
    }
}
