//
//  SessionLink.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

/// Lets the networking layer reach SessionManager to end or interrupt a
/// session. The reference is weak because SessionManager reaches the network
/// too, and two strong references would keep each other alive forever.
///
/// It is set once, in `AppDependencies.live()`, after SessionManager exists.
@MainActor
final class SessionLink {

    weak var session: SessionManager?

    init() {}
}
