//
//  OnboardingViewModelTests.swift
//  AppTemplateTests
//

import Testing
@testable import AppTemplate

@MainActor
struct OnboardingViewModelTests {

    // Records completion so a test can tell the flow ended without reaching into a session.
    private final class FinishSpy: @unchecked Sendable {
        private(set) var count = 0
        func record() { count += 1 }
    }

    private func makeViewModel(spy: FinishSpy) -> OnboardingViewModel {
        OnboardingViewModel { spy.record() }
    }

    @Test func startsOnTheFirstPage() {
        let viewModel = makeViewModel(spy: FinishSpy())
        #expect(viewModel.pageIndex == 0)
        #expect(viewModel.isLastPage == false)
    }

    @Test func nextAdvancesWithoutFinishing() async {
        let spy = FinishSpy()
        let viewModel = makeViewModel(spy: spy)

        await viewModel.next()

        #expect(viewModel.pageIndex == 1)
        #expect(spy.count == 0)
    }

    @Test func reachesTheLastPageAfterPagingThroughTheRest() async {
        let viewModel = makeViewModel(spy: FinishSpy())

        for _ in 1..<viewModel.pages.count {
            await viewModel.next()
        }

        #expect(viewModel.isLastPage)
    }

    // Would fail if `next` advanced past the end instead of ending the flow.
    @Test func nextOnTheLastPageFinishes() async {
        let spy = FinishSpy()
        let viewModel = makeViewModel(spy: spy)

        for _ in 1..<viewModel.pages.count {
            await viewModel.next()
        }
        await viewModel.next()

        #expect(spy.count == 1)
        #expect(viewModel.pageIndex == viewModel.pages.count - 1)
    }

    @Test func skipFinishesFromTheFirstPage() async {
        let spy = FinishSpy()
        let viewModel = makeViewModel(spy: spy)

        await viewModel.skip()

        #expect(spy.count == 1)
    }

    // A swipe writes the index back through the view model, so it has to accept a real page.
    @Test func swipingMovesToThePageSwipedTo() {
        let viewModel = makeViewModel(spy: FinishSpy())

        viewModel.moveTo(page: 1)

        #expect(viewModel.pageIndex == 1)
    }

    // Moves to a real page first, so the assertion cannot pass on the initial value alone: an
    // out of range index must leave the reader where they were.
    @Test func ignoresAPageIndexThatDoesNotExist() {
        let viewModel = makeViewModel(spy: FinishSpy())
        viewModel.moveTo(page: 1)

        viewModel.moveTo(page: 99)

        #expect(viewModel.pageIndex == 1)
    }
}
