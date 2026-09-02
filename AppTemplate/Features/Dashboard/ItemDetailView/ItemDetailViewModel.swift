//
//  ItemDetailViewModel.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class ItemDetailViewModel {

    var state: LoadState<Item> = .idle

    @ObservationIgnored private let itemID: Int
    @ObservationIgnored private let repository: any ItemRepository

    init(item: Item, repository: any ItemRepository) {
        self.itemID = item.id
        self.repository = repository
        self.state = .loaded(item)
    }

    init(itemID: Int, repository: any ItemRepository) {
        self.itemID = itemID
        self.repository = repository
    }

    func load(isRefresh: Bool = false) async {
        let isRefresh = isRefresh || state.value != nil

        if !isRefresh, state.value == nil {
            state = .loading
        }

        do {
            let item = try await repository.item(id: itemID)

            try Task.checkCancellation()
            state = .loaded(item)
        } catch {
            let apiError = error as? APIError ?? APIError.from(transportError: error)

            if apiError.isWorthReporting { Observability.crashes.record(apiError) }

            guard apiError.isUserFacing else { return }

            if isRefresh, state.value != nil { return }

            state = .failed(apiError)
        }
    }
}
