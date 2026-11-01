//
//  ProfileView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI
import UIKit

struct ProfileView: View {

    @State private var viewModel: ProfileViewModel
    @State private var pickedImage: UIImage?

    @Environment(Router<MainRoute>.self) private var router

    init(viewModel: ProfileViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(Text("Loading", comment: "Accessibility label for a loading spinner"))

            case let .loaded(user):
                profile(user)

            case .empty:
                ContentUnavailableView {
                    Label("Profile unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
                }

            case let .failed(error):
                ErrorStateView(error: error, retry: { await viewModel.load() })
            }
        }
        .navigationTitle(Text("Profile", comment: "Title of the profile screen"))
        .task {
            guard viewModel.state.needsLoad else { return }
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load(isRefresh: true)
        }
        .onChange(of: pickedImage) { _, image in
            guard let image else { return }
            Task {
                await viewModel.uploadAvatar(image)

                pickedImage = nil
            }
        }
        .safeAreaInset(edge: .bottom) {
            SignOutButton(signOut: viewModel.signOut)
        }
    }

    private func profile(_ user: User) -> some View {
        List {
            headerSection(user)
            accountSection(user)
            settingsSection
        }
    }

    private func headerSection(_ user: User) -> some View {
        Section {
            HStack(spacing: Theme.Spacing.lg) {
                AvatarView(user: user, size: Theme.Size.avatarMedium)
                    .overlay {
                        if viewModel.avatarUpload.isRunning {
                            Circle()
                                .fill(.black.opacity(0.4))
                                .overlay { ProgressView().tint(.white) }
                        }
                    }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(user.fullName)
                        .font(Theme.Font.cardTitle)

                    Text(user.email)
                        .font(Theme.Font.secondary)
                        .foregroundStyle(Theme.Color.secondaryText)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
            .accessibilityElement(children: .combine)

            ImagePicker(image: $pickedImage) {
                Label {
                    Text("Change Photo", comment: "Button that opens the photo picker")
                } icon: {
                    Image(systemName: "photo")
                }
            }
            .disabled(viewModel.avatarUpload.isRunning)

            if let error = viewModel.avatarUpload.errorMessage {
                InlineErrorText(error)
            }
        }
    }

    private func accountSection(_ user: User) -> some View {
        Section {
            LabeledContent {
                Text(user.username)
            } label: {
                Text("Username", comment: "Label for the username row on the profile screen")
            }

            LabeledContent {

                Text(verbatim: user.id.uuidString)
            } label: {
                Text("User ID", comment: "Label for the user ID row on the profile screen")
            }
        } header: {
            Text("Account", comment: "Header of the account section on the profile screen")
        }
    }

    private var settingsSection: some View {
        Section {
            Button {
                router.push(.settings)
            } label: {
                Label {
                    Text("Settings", comment: "Button that opens the settings screen")
                } icon: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

}

#if DEBUG

#Preview {
    PreviewHost { dependencies in
        NavigationStack {
            ProfileView(viewModel: dependencies.makeProfileViewModel())
        }
        .environment(Router<MainRoute>())
        .environment(AppNavigator())
    }
}

#endif
