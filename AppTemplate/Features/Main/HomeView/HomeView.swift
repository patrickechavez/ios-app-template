//
//  HomeView.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct HomeView: View {

    @State private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
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

            case let .loaded(items):
                list(items)

            case .empty:
                ContentUnavailableView {
                    Label(
                        viewModel.isSearching ? "No matches" : "No items yet",
                        systemImage: viewModel.isSearching ? "magnifyingglass" : "tray"
                    )
                } description: {
                    Text(viewModel.isSearching ? "Try a different search term." : "Items you add will appear here.")
                }

            case let .failed(error):
                ErrorStateView(error: error, retry: { await viewModel.load() })
            }
        }
        .navigationTitle(Text("Items", comment: "Title of the items list screen"))
        .searchable(
            text: $viewModel.searchText,
            prompt: Text("Search items", comment: "Placeholder in the items search field")
        )

        .task(id: viewModel.searchText) {
            if !viewModel.searchText.isEmpty {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
            }
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load(isRefresh: true)
        }
    }

    private func list(_ items: [Item]) -> some View {
        List {
            ForEach(items) { item in
                ItemRow(item: item)
                    .task {

                        if viewModel.shouldLoadMore(after: item) {
                            await viewModel.loadMore()
                        }
                    }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .accessibilityLabel(Text(
                    "Loading more items",
                    comment: "Accessibility label for the pagination spinner"
                ))
            }
        }
        .listStyle(.plain)
    }
}

private struct ItemRow: View {

    let item: Item

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            CachedAsyncImage(url: item.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                SkeletonView(cornerRadius: Theme.Radius.md)
            }
            .frame(width: Theme.Size.thumbnail, height: Theme.Size.thumbnail)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

            VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                Text(item.title)
                    .font(Theme.Font.cardTitle)
                    .lineLimit(2)

                Text(item.price, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(Theme.Font.secondary)
                    .foregroundStyle(Theme.Color.secondaryText)
            }

            Spacer(minLength: Theme.Spacing.sm)
        }
        .padding(.vertical, Theme.Spacing.xs)

        .accessibilityElement(children: .combine)
    }
}

#if DEBUG

#Preview {
    PreviewHost { dependencies in
        NavigationStack {
            HomeView(viewModel: dependencies.makeHomeViewModel())
        }
    }
}

#endif
