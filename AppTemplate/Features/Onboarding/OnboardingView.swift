//
//  OnboardingView.swift
//  AppTemplate
//

import SwiftUI

struct OnboardingView: View {

    @State private var viewModel: OnboardingViewModel

    init(viewModel: OnboardingViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    Task { await viewModel.skip() }
                } label: {
                    Text("Skip", comment: "Button that dismisses onboarding without reading it")
                }
                .padding(Theme.Spacing.lg)
            }

            TabView(selection: pageSelection) {
                ForEach(viewModel.pages) { page in
                    OnboardingPageView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                Task { await viewModel.next() }
            } label: {
                buttonTitle
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(Theme.Spacing.xxl)
        }
        .animation(Theme.Animation.standard, value: viewModel.pageIndex)
    }

    // The view model owns the index, so selection reads from it and writes back through it.
    private var pageSelection: Binding<Int> {
        Binding(
            get: { viewModel.pageIndex },
            set: { viewModel.moveTo(page: $0) }
        )
    }

    private var buttonTitle: Text {
        viewModel.isLastPage
            ? Text("Get Started", comment: "Button that finishes onboarding")
            : Text("Next", comment: "Button that moves to the next onboarding page")
    }
}

private struct OnboardingPageView: View {

    let page: OnboardingPage

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: page.symbol)
                .font(.system(size: 72))
                .foregroundStyle(Theme.Color.accent)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.md) {
                Text(page.title)
                    .font(Theme.Font.screenTitle)
                    .multilineTextAlignment(.center)

                Text(page.message)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding(Theme.Spacing.xxl)
    }
}
