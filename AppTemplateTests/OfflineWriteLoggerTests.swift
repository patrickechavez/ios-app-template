//
//  OfflineWriteLoggerTests.swift
//  AppTemplateTests
//

import Testing
@testable import AppTemplate

struct OfflineWriteLoggerTests {

    @Test func marksTheWriteAsNeverSent() {
        let summary = OfflineWriteLogger.summary(.post)

        #expect(summary.hasPrefix("⇢ POST  (offline)"))
    }

    @Test func includesThePathWhenGiven() {
        let summary = OfflineWriteLogger.summary(.patch, path: "/rest/v1/items")

        #expect(summary.hasPrefix("⇢ PATCH /rest/v1/items  (offline)"))
    }

    @Test func stampsTheBuildThatWroteTheRow() {
        let summary = OfflineWriteLogger.summary(.delete)

        #expect(summary.contains("client=\(ClientMetadata.appVersion)(\(ClientMetadata.appBuild))"))
    }
}
