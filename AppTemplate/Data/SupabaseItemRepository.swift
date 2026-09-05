//
//  SupabaseItemRepository.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

// Speaks PostgREST — Supabase's auto-generated table API — instead of a
// generic REST backend. Kept separate from LiveItemRepository/APIRoute.Items
// so the generic shape (items/{id} path addressing) stays correct for any
// other backend; nothing here is shared with it.
//
// Three things PostgREST needs that a typical REST API doesn't:
//   1. Mounted at rest/v1/, not the bare table name.
//   2. No path-style addressing — a single row is a query filter
//      (?id=eq.<uuid>), and that always comes back as an array, even for
//      one match — unwrap it with Accept: application/vnd.pgrst.object+json.
//   3. INSERT/UPDATE return an empty body unless asked for one via
//      Prefer: return=representation.
nonisolated struct SupabaseItemRepository: ItemRepository {

    private let api: any APIClient
    private static let path = "rest/v1/items"

    init(api: any APIClient) {
        self.api = api
    }

    func items(_ request: PageRequest) async throws -> Page<Item> {
        try await api.get(Self.path, query: request.queryItems)
    }

    // Not yet a real PostgREST filter — still sends the generic `q` param,
    // which PostgREST ignores, so this returns every row unfiltered. Needs
    // an `or=(title.ilike.*term*,description.ilike.*term*)` filter to work.
    func search(_ term: String, page: PageRequest) async throws -> Page<Item> {
        var query = page.queryItems
        query.append(URLQueryItem(name: "q", value: term))
        return try await api.get(Self.path, query: query)
    }

    func item(id: UUID) async throws -> Item {
        let endpoint = Endpoint(
            Self.path,
            query: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            headers: ["Accept": "application/vnd.pgrst.object+json"]
        )
        return try await api.send(endpoint)
    }

    func create(_ draft: ItemDraft) async throws -> Item {
        let endpoint = try Endpoint(
            Self.path,
            method: .post,
            headers: [
                "Prefer": "return=representation",
                "Accept": "application/vnd.pgrst.object+json"
            ],
            body: .json(draft)
        )
        return try await api.send(endpoint)
    }

    func update(id: UUID, draft: ItemDraft) async throws -> Item {
        let endpoint = try Endpoint(
            Self.path,
            method: .patch,
            query: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            headers: [
                "Prefer": "return=representation",
                "Accept": "application/vnd.pgrst.object+json"
            ],
            body: .json(draft)
        )
        return try await api.send(endpoint)
    }

    // No headers needed — DELETE's response body is discarded either way.
    func delete(id: UUID) async throws {
        let endpoint = Endpoint(
            Self.path,
            method: .delete,
            query: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]
        )
        try await api.send(endpoint)
    }
}
