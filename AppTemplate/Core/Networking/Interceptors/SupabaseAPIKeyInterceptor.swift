//
//  SupabaseAPIKeyInterceptor.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

// Supabase requires this on every request, even authenticated ones —
// it identifies the project; Authorization identifies the user.
struct SupabaseAPIKeyInterceptor: RequestInterceptor {

    private let anonKey: String

    init(anonKey: String) {
        self.anonKey = anonKey
    }

    func adapt(_ request: URLRequest, for endpoint: Endpoint) async throws -> URLRequest {
        var request = request
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        return request
    }
}
