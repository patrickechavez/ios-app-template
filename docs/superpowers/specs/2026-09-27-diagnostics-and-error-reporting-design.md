# Diagnostics and Error Reporting Design

**Status:** approved, not yet implemented
**Scope:** ios-app-template only. Gabay is out of scope.

## Goal

Close two gaps in the template's observability:

1. **No performance signal.** Nothing tells you the app hung, or that an
   operation was slow, at your desk or anywhere else.
2. **Error reporting is network-only.** `APIError.classify` is the single
   reporting funnel and it lives in the networking layer, so a Keychain
   failure or an image failure reaches Crashlytics never.

## What already exists, and is not changing

The audit that produced this spec found the crash story in good shape. None of
the following is being altered:

- `firebase-ios-sdk 12.17.0` linked, with a `Copy GoogleService-Info.plist`
  build phase that selects per `$CONFIGURATION` and fails the build on a bundle
  ID mismatch, and an `Upload Crashlytics dSYM` phase that skips Development.
- `APIError.classify` as one funnel every catch block goes through, recording a
  breadcrumb on every failure and a non-fatal when `isWorthReporting`.
- `isWorthReporting` reporting 5xx, `decodingFailed`, `invalidResponse` and
  `serverTrustFailed`, and staying quiet on 401, 403, 404, 409, 422, 429,
  offline, timeout and cancellation. Those are expected conditions, not defects.
- `SessionManager` calling `crashes.setUser(id:)`, so crashes name a user.
- 16 breadcrumb sites, 6 analytics events, `AppLogger` with 6 categories,
  `LogFormat` redaction, `LoggingInterceptor`, `OfflineWriteLogger`.

## Non-goals

- **This does not replace Instruments.** Time Profiler, Leaks, Allocations and
  Swift Concurrency need no code and already work. Call stacks, retain cycles
  and allocation attribution cannot be turned into log lines. What is built
  here tells you *that* something is wrong so you know to open Instruments,
  which tells you *why*. The spec is a smoke alarm, not an investigation.
- **MetricKit is deliberately out of scope.** It is the production counterpart
  to the watchdog, delivering hang diagnostics with call stacks from real
  devices roughly once a day. It is useless at a desk, it has no dashboard, and
  the template has no users yet. It deserves its own spec once an app built on
  this template ships. Recorded here so the omission is a decision, not an
  oversight.
- **No new configuration key.** `API_LOGGING_ENABLED` already gates
  `LoggingInterceptor` and `OfflineWriteLogger`, the latter of which lives in
  `Core/Observability/`, so the template already treats it as a general verbose
  diagnostics switch rather than a network-only one. Adding a ninth key to three
  xcconfigs, `Info.plist`, `APIConfig` and the README would serve only a
  hypothetical need to run the watchdog on Staging without body logging, which
  nobody has asked for.
- **Analytics coverage is not widened here.** Six events is thin, but that is an
  app-level concern, not a template one.

## Part 1: Performance

Three units in `Core/Observability/`, mirroring how the template already splits
`AnalyticsTracking`, `CrashReporting` and `Breadcrumb` into small pieces behind
an `install` seam.

### `Signposts.swift`

One `OSSignposter` on the `.pointsOfInterest` category, so intervals appear in
the Points of Interest track in Instruments with no extra configuration.

```swift
import Foundation
import os

// One signposter for the app. `.pointsOfInterest` is what puts intervals in
// Instruments' Points of Interest track without any per-trace setup.
enum Signposts {

    static let signposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "AppTemplate",
        category: .pointsOfInterest
    )
}
```

**Signposts are deliberately ungated.** `OSSignposter` costs a load and a branch
when no tool is listening. Gating them behind `API_LOGGING_ENABLED` would remove
them exactly when someone attaches Instruments to a Staging build, which is the
one moment they are wanted.

### `DiagnosticsDefaults.swift`

The thresholds, and the two `Duration` readouts everything below needs. `Duration`
exposes only `components`, so these are not optional conveniences.

```swift
import Foundation

enum DiagnosticsDefaults {
    static let slowOperation: Duration = .milliseconds(100)
    static let mainThreadStall: Duration = .milliseconds(250)
    static let watchdogPoll: Duration = .milliseconds(100)
}

extension Duration {

    var milliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }

    var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
```

### `Logger+Measure.swift`

`measure` as an extension on `Logger`, so a call site picks its own category for
free and reads naturally:

```swift
AppLogger.data.measure("decode page") { try decoder.decode(Page<Item>.self, from: data) }
await AppLogger.network.measure("upload avatar") { try await api.send(endpoint) }
```

```swift
import Foundation
import os

extension Logger {

    func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        let state = Signposts.signposter.beginInterval(name)
        let start = ContinuousClock.now

        defer {
            Signposts.signposter.endInterval(name, state)
            record(name, elapsed: ContinuousClock.now - start)
        }
        return try work()
    }

    func measure<T>(_ name: StaticString, _ work: () async throws -> T) async rethrows -> T {
        let state = Signposts.signposter.beginInterval(name)
        let start = ContinuousClock.now

        defer {
            Signposts.signposter.endInterval(name, state)
            record(name, elapsed: ContinuousClock.now - start)
        }
        return try await work()
    }

    // The signpost above always fires; only this line is gated, because a log
    // line costs a formatted string and a signpost does not.
    private func record(_ name: StaticString, elapsed: Duration) {
        guard APIConfig.isLoggingEnabled else { return }

        let ms = elapsed.milliseconds
        if elapsed >= DiagnosticsDefaults.slowOperation {
            notice("⏱ \(name, privacy: .public) took \(ms, privacy: .public)ms")
        } else {
            debug("⏱ \(name, privacy: .public) took \(ms, privacy: .public)ms")
        }
    }
}
```

Both overloads `rethrows` and return the wrapped value, so they drop into an
existing expression without restructuring it, and the `defer` means a throwing
body still closes its interval and still logs.

`name` is `StaticString` because `OSSignposter.beginInterval` requires one. That
rules out a dynamic label such as an interpolated URL. An operation needing one
should put it in the surrounding log line, not the signpost name.

The `.notice` versus `.debug` split is the whole point: it makes slowness
greppable rather than buried in a wall of timings.

### `MainThreadWatchdog.swift`

Ping and pong, not a `CFRunLoopObserver`. A background timer stamps a time and
dispatches a block to the main queue to clear it. If a later tick finds the
stamp uncleared, the main queue has not drained.

This measures the thing that actually matters, is simpler than a runloop
observer, and its whole state is one optional instant behind an
`OSAllocatedUnfairLock`, which the template already uses in `Breadcrumb` and
`APIClient`.

```swift
import Foundation
import os

// Reports when the main queue stops draining. Development only: `start()` is a
// no-op unless logging is enabled.
final class MainThreadWatchdog: @unchecked Sendable {

    private struct State {
        var pingedAt: ContinuousClock.Instant?
        var hasReported = false
    }

    private let threshold: Duration
    private let poll: Duration
    private let onStall: @Sendable (Duration) -> Void

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let queue = DispatchQueue(label: "diagnostics.watchdog")
    private var timer: DispatchSourceTimer?

    init(
        threshold: Duration = DiagnosticsDefaults.mainThreadStall,
        poll: Duration = DiagnosticsDefaults.watchdogPoll,
        onStall: @escaping @Sendable (Duration) -> Void = MainThreadWatchdog.log
    ) {
        self.threshold = threshold
        self.poll = poll
        self.onStall = onStall
    }

    static let log: @Sendable (Duration) -> Void = { stalled in
        AppLogger.lifecycle.notice(
            "⚠️ Main thread blocked for at least \(stalled.milliseconds, privacy: .public)ms"
        )
    }

    func start() {
        guard APIConfig.isLoggingEnabled, timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + poll, repeating: poll.timeInterval)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        let stall: Duration? = state.withLock { state in
            guard let pingedAt = state.pingedAt else {
                // No ping outstanding: send one and let the main queue clear it.
                state.pingedAt = ContinuousClock.now
                state.hasReported = false
                return nil
            }

            // The previous ping is still unanswered, so the main queue has not
            // drained since it was sent.
            let elapsed = ContinuousClock.now - pingedAt
            guard elapsed >= threshold, !state.hasReported else { return nil }
            state.hasReported = true
            return elapsed
        }

        if let stall {
            onStall(stall)
            return
        }

        // Outside the lock: never dispatch while holding it.
        DispatchQueue.main.async { [state] in
            state.withLock { $0.pingedAt = nil }
        }
    }
}
```

Two properties worth stating plainly:

- It reports **once per stall**, at the moment the stall crosses the threshold,
  and the reported duration is "at least this long", not the total. A watchdog
  that waits for recovery to report the true total never reports a permanent
  hang, which is the case you most want to hear about.
- `onStall` is the testability seam. A test blocks the main thread deliberately
  and asserts on the reported duration without parsing console output.

### Integration

`Observability.install` gains one line, matching how it already installs
`Breadcrumb`:

```swift
static func install(analytics: any AnalyticsTracking, crashes: any CrashReporting) {
    Self.analytics = analytics
    Self.crashes = crashes
    Breadcrumb.install(crashes)
    watchdog.start()
}

private static let watchdog = MainThreadWatchdog()
```

Three call sites get `measure`, all in code the template already owns, so no app
built on the template needs to do anything to benefit:

| Site | Interval covers |
|---|---|
| `URLSessionAPIClient.perform` | one logical request, retries included |
| `ImageLoader.image(for:)` | one image load |
| `TokenRefreshCoordinator.refresh` | refresh latency, invisible today and on the critical path of every 401 |

`perform` is chosen over `attemptOnce` deliberately: it gives "this call took
4.2s across 3 attempts" rather than three unrelated intervals.

## Part 2: Error reporting beyond the network

### The problem, precisely

`KeychainError.unhandled(status:)` and `ImageLoaderError` are both thrown and
both logged at `.error`, and neither reaches Crashlytics, because
`APIError.classify` only understands `APIError`. A Keychain write failure means
a user silently stops staying signed in.

Three sites also discard an error outright:

| Site | Verdict |
|---|---|
| `SessionManager.swift:95` `try? await users.currentUser()` | **Fix.** A failed profile fetch leaves a half-signed-in state with nothing recorded. |
| `ImageLoader` catch, reached via `CachedAsyncImage.swift:41` | **Report at the throw site**, keep the `try?` at the call site, since a placeholder image is the correct UX. |
| `AuthInterceptor.swift:24` `try? await coordinator.refresh(...)` | **Leave silent, document why.** `TokenRefreshCoordinator` already reports its own failure; reporting again would double-count. |

### `ReportableError`

```swift
// Anything thrown that is worth a non-fatal. Defaults to true: an error nobody
// has classified is more likely a defect than an expected condition.
protocol ReportableError: Error {
    var isWorthReporting: Bool { get }
}

extension ReportableError {
    var isWorthReporting: Bool { true }
}
```

### `Diagnostics.report`

```swift
@MainActor
enum Diagnostics {

    /// One funnel for any error, network or not. Breadcrumbs everything,
    /// reports what is worth reporting.
    static func report(_ error: any Error, context: @autoclosure () -> String) {
        Breadcrumb.record("\(context()): \(error)")

        let isWorthReporting = (error as? any ReportableError)?.isWorthReporting ?? true
        if isWorthReporting {
            Observability.crashes.record(error)
        }
    }
}
```

`APIError.classify` keeps its signature and delegates, so its behaviour is
unchanged byte for byte:

```swift
@MainActor
static func classify(_ error: any Error) -> APIError {
    let apiError = error as? APIError ?? .from(transportError: error)
    Diagnostics.report(apiError, context: "Request failed")
    return apiError
}
```

### Conformances

`APIError` conforms using the `isWorthReporting` it already has, so nothing
about its filtering changes.

`KeychainError` takes the default of `true`. `errSecItemNotFound` is already
handled without throwing, so any `KeychainError` that escapes is unexpected.

`ImageLoaderError` mirrors `APIError`'s philosophy rather than the default:

```swift
extension ImageLoaderError: ReportableError {

    var isWorthReporting: Bool {
        switch self {
        case .invalidImageData: true
        case let .httpStatus(code): code >= 500
        }
    }
}
```

A missing image is a content problem, not a defect. A server error or bytes that
are not an image is worth knowing about.

## Error handling

Nothing in this spec is allowed to fail the operation it observes.

`measure` returns the body's value and rethrows its error unchanged; its own
logging cannot throw. The watchdog runs on its own queue and only reads a clock
and takes a lock. `Diagnostics.report` is called from catch blocks that already
have an error in hand and returns `Void`, so a reporting failure cannot mask the
original error.

The watchdog never calls into anything while holding its lock, following the
same discipline as `TokenRefreshCoordinator`.

## Testing

| Unit | Test |
|---|---|
| `Logger.measure` | Returns the body's value; rethrows the body's error; runs the body exactly once. Both sync and async overloads. |
| `MainThreadWatchdog` | Inject `onStall`, block the main thread past the threshold, assert it fires once with a duration at or above the threshold. A second test asserts it does not fire when the main thread is responsive. |
| `Diagnostics.report` | Install a stub `CrashReporting` into `Observability.crashes`. Assert a `ReportableError` with `isWorthReporting == false` records a breadcrumb but no non-fatal, and that one with `true` records both. |
| `ReportableError` default | A bare conforming error reports by default. |
| `ImageLoaderError` | `.invalidImageData` reports; `.httpStatus(404)` does not; `.httpStatus(500)` does. |

`Signposts` is not tested: asserting on `OSSignposter` means asserting on
Apple's implementation.

`Observability.crashes` is a settable static, so a stub installs without new
machinery. `Core/Testing/Mocks.swift` holds the existing mocks and gains a
`MockCrashReporter` that records what it was given.

## Files

| Path | Change |
|---|---|
| `Core/Observability/Signposts.swift` | Create |
| `Core/Observability/DiagnosticsDefaults.swift` | Create, thresholds and the `Duration` readouts |
| `Core/Observability/Logger+Measure.swift` | Create |
| `Core/Observability/MainThreadWatchdog.swift` | Create |
| `Core/Observability/Diagnostics.swift` | Create, `ReportableError` and `Diagnostics.report` |
| `Core/Observability/Observability.swift` | Start the watchdog in `install` |
| `Core/Networking/APIError.swift` | `classify` delegates; conform to `ReportableError` |
| `Core/Networking/APIClient.swift` | `measure` around `perform` |
| `Core/Storage/TokenStore.swift` | `KeychainError: ReportableError` |
| `Core/Images/ImageLoader.swift` | `measure`; conformance; report at the catch |
| `Core/Images/CachedAsyncImage.swift` | Comment on the deliberate `try?` |
| `Core/Session/SessionManager.swift` | Replace `try?` with do/catch plus report |
| `Core/Session/TokenRefreshCoordinator.swift` | `measure` around `refresh` |
| `Core/Networking/Interceptors/AuthInterceptor.swift` | Comment on the deliberate `try?` |
| `Core/Testing/Mocks.swift` | Add `MockCrashReporter` |
| `README.md` | A Diagnostics section |

## Open question

The template has 35 tests and no standing instruction against adding more. This
spec assumes tests ship with the implementation. The "no new test cases"
instruction in play elsewhere applies to Gabay, not here.
