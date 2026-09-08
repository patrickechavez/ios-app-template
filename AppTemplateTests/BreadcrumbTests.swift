//
//  BreadcrumbTests.swift
//  AppTemplateTests
//

import Testing
@testable import AppTemplate

// Serialized because Breadcrumb holds one process-wide reporter.
@Suite(.serialized)
struct BreadcrumbTests {

    private final class SpyCrashReporter: CrashReporting, @unchecked Sendable {
        var messages: [String] = []

        func record(_ error: Error) {}

        func log(_ message: String) { messages.append(message) }

        func setUser(id: String?) {}
    }

    @Test func sendsRecordedMessagesToTheInstalledReporter() {
        let spy = SpyCrashReporter()
        Breadcrumb.install(spy)
        defer { Breadcrumb.install(NoopCrashReporter()) }

        Breadcrumb.record("Signed in")

        #expect(spy.messages == ["Signed in"])
    }

    @Test func leavesABreadcrumbForEveryLoggedEvent() {
        let spy = SpyCrashReporter()
        Breadcrumb.install(spy)
        defer { Breadcrumb.install(NoopCrashReporter()) }

        AppLogger.auth.breadcrumb("Access token refreshed")
        AppLogger.lifecycle.breadcrumb("Signed out")

        #expect(spy.messages == ["Access token refreshed", "Signed out"])
    }
}
