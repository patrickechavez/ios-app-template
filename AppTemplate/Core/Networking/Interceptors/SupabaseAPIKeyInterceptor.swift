//
//  SupabaseAPIKeyInterceptor.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

// Supabase's gateway rejects every request — even authenticated ones — that
// doesn't carry this header. It identifies the project; Authorization (added
// separately, by AuthInterceptor) identifies the signed-in user.
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
