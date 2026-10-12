//
//  OnboardingViewModel.swift
//  AppTemplate
//

import Foundation
import Observation

// Paging state for the first-run flow. Finishing and skipping both end the flow the same way,
// because a reader who skips has still decided they are done with it.
@Observable
@MainActor
final class OnboardingViewModel {

    let pages: [OnboardingPage]

    private(set) var pageIndex: Int = 0

    @ObservationIgnored private let onFinish: () async -> Void

    init(
        pages: [OnboardingPage] = OnboardingPage.defaults,
        onFinish: @escaping () async -> Void
    ) {
        self.pages = pages
        self.onFinish = onFinish
    }

    var isLastPage: Bool {
        pageIndex >= pages.count - 1
    }

    // Advances, or ends the flow when there is nothing left to show.
    func next() async {
        guard !isLastPage else {
            await onFinish()
            return
        }
        pageIndex += 1
    }

    func skip() async {
        await onFinish()
    }

    // Swiping is the other way to change page, so the index still moves through the view model
    // rather than being written directly by the view.
    func moveTo(page index: Int) {
        guard pages.indices.contains(index) else { return }
        pageIndex = index
    }
}
