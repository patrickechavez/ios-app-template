# Diagnostics and Error Reporting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the template a performance signal it does not have, and widen error reporting past the networking layer.

**Architecture:** Four new files in `Core/Observability/`, following how that folder already splits `AnalyticsTracking`, `CrashReporting` and `Breadcrumb` into small units behind an `install` seam. Signposts and a `measure` helper make operations visible; a ping/pong watchdog reports a stalled main queue; a `ReportableError` protocol and one `Diagnostics.report` funnel let any error reach Crashlytics, not only `APIError`.

**Tech Stack:** Swift 6 strict concurrency, `os` (`OSSignposter`, `Logger`, `OSAllocatedUnfairLock`), Swift Testing, Firebase Crashlytics behind the existing protocol seams.

**Spec:** `docs/superpowers/specs/2026-09-27-diagnostics-and-error-reporting-design.md`

## Global Constraints

- **This is detection, not diagnosis.** It tells you *that* something is wrong so you open Instruments, which tells you *why*. Do not add anything that claims to replace Time Profiler, Leaks or Allocations.
- **MetricKit is out of scope.** Do not add it, do not import it.
- **No new configuration key.** Reuse `API_LOGGING_ENABLED` via `APIConfig.isLoggingEnabled`, which already gates `LoggingInterceptor` and `OfflineWriteLogger`.
- **Signposts are never gated.** Only the duration log lines and the watchdog sit behind `isLoggingEnabled`.
- **`APIError` behaviour must not change.** Its `isWorthReporting` filter and the breadcrumb text `"Request failed: <error>"` stay exactly as they are.
- **Tests ship with this work.** The "no new test cases" instruction in play elsewhere applies to Gabay, not to this repository.
- **NEVER run `xcodebuild` or `xcrun simctl`.** The user runs all builds and tests personally. `xcrun --show-sdk-path` and `xcrun --find` are permitted and are used by the verification script.
- **Never edit `AppTemplate.xcodeproj/project.pbxproj`.** All four file groups are `PBXFileSystemSynchronizedRootGroup`, so files under `AppTemplate/` and `AppTemplateTests/` are picked up automatically.
- **No em dashes** anywhere: code, comments, docs, commit messages.
- **No attribution trailers** in commit messages. No `Co-Authored-By`, no `Generated with`. Verify with `git log -1 --format=%B` after every commit rather than trusting intent.
- Swift 6 strict concurrency. No data races. Never call out to anything while holding a lock.

## Deviation from the spec, recorded

The spec writes `Diagnostics.report(_:context:)` with `context` as an `@autoclosure`. **Use a plain `String`.** The breadcrumb always interpolates the context, so the autoclosure is never skipped and buys nothing, while making the function awkward to call across an actor boundary from `ImageLoader`. Signature becomes:

```swift
static func report(_ error: any Error, context: String)
```

## File structure

| Path | Responsibility |
|---|---|
| `Core/Observability/DiagnosticsDefaults.swift` | Thresholds, plus the two `Duration` readouts everything else needs |
| `Core/Observability/Signposts.swift` | The single `OSSignposter` |
| `Core/Observability/Logger+Measure.swift` | `measure` on `Logger`: signpost interval plus a duration line |
| `Core/Observability/MainThreadWatchdog.swift` | Reports a main queue that stops draining |
| `Core/Observability/Diagnostics.swift` | `ReportableError` and the `report` funnel |
| `Scripts/typecheck.sh` | Whole-module typecheck, since agents cannot build |

---

### Task 1: Diagnostics primitives and the verification script

Nothing here has behaviour worth arguing about, but everything later depends on it, and the `Duration` readouts are easy to get wrong because `Duration` exposes only `components`.

**Files:**
- Create: `AppTemplate/Core/Observability/DiagnosticsDefaults.swift`
- Create: `AppTemplate/Core/Observability/Signposts.swift`
- Create: `Scripts/typecheck.sh`
- Test: `AppTemplateTests/DiagnosticsDefaultsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `DiagnosticsDefaults.slowOperation`, `.mainThreadStall`, `.watchdogPoll`, all `Duration`. `Duration.milliseconds -> Double` and `Duration.timeInterval -> TimeInterval`. `Signposts.signposter -> OSSignposter`. `./Scripts/typecheck.sh`, exit 0 when clean.

- [ ] **Step 1: Create the verification script**

Agents cannot run the build, so this is the mechanical check that a change still compiles. Write `Scripts/typecheck.sh`:

```bash
#!/bin/bash
# Typechecks the app and test targets as one module under the project's flags.
# Agents cannot run xcodebuild, so this is the check that a change compiles. It
# is not a substitute for the real build or for running the tests, and because
# it merges both targets it cannot catch anything that depends on the boundary
# between them, such as a symbol made private in the app but read from a test.
set -euo pipefail

cd "$(dirname "$0")/.."

SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
PLUGIN="$(dirname "$(xcrun --find swift)")/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

COLLISIONS=$(find AppTemplate AppTemplateTests -name '*.swift' ! -name 'FirebaseObservability.swift' \
  -exec basename {} \; | sort | uniq -d)
if [ -n "$COLLISIONS" ]; then
  echo "Duplicate basenames, cannot typecheck as one module:" >&2
  echo "$COLLISIONS" >&2
  exit 1
fi

# FirebaseObservability.swift is the only file importing the SDK, which plain
# swiftc cannot resolve. It is excluded and its one symbol is stubbed.
find AppTemplate AppTemplateTests -name '*.swift' ! -name 'FirebaseObservability.swift' \
  -exec cp {} "$WORK"/ \;

perl -pi -e 's/^\@testable import AppTemplate$//; s/^import AppTemplate$//' "$WORK"/*.swift

cat > "$WORK"/__FirebaseStub.swift <<'STUB'
enum FirebaseBootstrap {
    static func start() -> (analytics: any AnalyticsTracking, crashes: any CrashReporting)? { nil }
}
STUB

echo "Typechecking $(ls "$WORK"/*.swift | wc -l | tr -d ' ') files..."

# -DDEVELOPMENT so Core/Testing/Mocks.swift, which is behind #if DEVELOPMENT,
# is compiled rather than silently skipped.
swiftc -swift-version 6 -typecheck -module-name AppTemplate -DDEVELOPMENT \
  -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
  -F "$SDK/../../Library/Frameworks" \
  -load-plugin-library "$PLUGIN" \
  "$WORK"/*.swift

echo "Clean."
```

Then `chmod +x Scripts/typecheck.sh`.

- [ ] **Step 2: Run it to record the baseline**

Run: `./Scripts/typecheck.sh`

Expected: `Typechecking 109 files...`, then one pre-existing warning and `Clean.`:

```
ImagePicker.swift:21:13: warning: capture of non-Sendable type 'Label.Type' in an isolated closure
```

That warning exists today and is not yours. Do not fix it. If anything else appears, stop and report BLOCKED.

- [ ] **Step 3: Write the failing test**

Create `AppTemplateTests/DiagnosticsDefaultsTests.swift`:

```swift
//
//  DiagnosticsDefaultsTests.swift
//  AppTemplateTests
//

import Foundation
import Testing
@testable import AppTemplate

struct DiagnosticsDefaultsTests {

    @Test func readsWholeMilliseconds() {
        #expect(Duration.milliseconds(250).milliseconds == 250)
    }

    @Test func readsSubMillisecondPrecision() {
        #expect(Duration.microseconds(1500).milliseconds == 1.5)
    }

    @Test func readsSecondsAsAnInterval() {
        #expect(Duration.milliseconds(250).timeInterval == 0.25)
    }

    @Test func readsMultipleSecondsAsMilliseconds() {
        #expect(Duration.seconds(2.5).milliseconds == 2500)
    }

    @Test func thresholdsAreOrderedSensibly() {
        // A poll slower than the stall threshold could not detect it.
        #expect(DiagnosticsDefaults.watchdogPoll < DiagnosticsDefaults.mainThreadStall)
    }
}
```

- [ ] **Step 4: Run it to verify it fails**

Run: `./Scripts/typecheck.sh`

Expected: FAIL, with `cannot find 'DiagnosticsDefaults' in scope` and `value of type 'Duration' has no member 'milliseconds'`.

- [ ] **Step 5: Create `DiagnosticsDefaults.swift`**

```swift
//
//  DiagnosticsDefaults.swift
//  AppTemplate
//

import Foundation

enum DiagnosticsDefaults {

    /// A `measure` run at or above this logs at `.notice` instead of `.debug`.
    static let slowOperation: Duration = .milliseconds(100)

    /// A main queue that has not drained for this long is reported.
    static let mainThreadStall: Duration = .milliseconds(250)

    /// How often the watchdog checks. Must stay below `mainThreadStall`.
    static let watchdogPoll: Duration = .milliseconds(100)
}

// `Duration` exposes only `components`, so every readout needs these.
extension Duration {

    var milliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }

    var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
```

- [ ] **Step 6: Create `Signposts.swift`**

```swift
//
//  Signposts.swift
//  AppTemplate
//

import Foundation
import os

// One signposter for the app. `.pointsOfInterest` is what puts intervals in
// Instruments' Points of Interest track with no per-trace setup.
//
// Never gated: OSSignposter costs a load and a branch when no tool is
// listening, and gating it would remove it exactly when someone attaches
// Instruments to a Staging build.
enum Signposts {

    static let signposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "AppTemplate",
        category: .pointsOfInterest
    )
}
```

- [ ] **Step 7: Verify**

Run: `./Scripts/typecheck.sh`

Expected: `Typechecking 112 files...` then `Clean.`, with only the pre-existing `ImagePicker.swift` warning.

- [ ] **Step 8: Commit**

```bash
git add AppTemplate/Core/Observability/DiagnosticsDefaults.swift \
        AppTemplate/Core/Observability/Signposts.swift \
        AppTemplateTests/DiagnosticsDefaultsTests.swift \
        Scripts/typecheck.sh
git commit -m "[main] Add diagnostics thresholds and the signposter"
git log -1 --format=%B
```

The output must carry no attribution trailer. Amend if it does.

---

### Task 2: `measure` on `Logger`

**Files:**
- Create: `AppTemplate/Core/Observability/Logger+Measure.swift`
- Test: `AppTemplateTests/LoggerMeasureTests.swift`

**Interfaces:**
- Consumes: `DiagnosticsDefaults.slowOperation`, `Duration.milliseconds`, `Signposts.signposter` from Task 1.
- Produces: `Logger.measure(_ name: StaticString, _ work: () throws -> T) rethrows -> T` and an `async` overload with the same shape.

- [ ] **Step 1: Write the failing test**

Create `AppTemplateTests/LoggerMeasureTests.swift`:

```swift
//
//  LoggerMeasureTests.swift
//  AppTemplateTests
//

import Foundation
import Testing
@testable import AppTemplate

struct LoggerMeasureTests {

    private struct Boom: Error, Equatable {}

    @Test func returnsTheBodysValue() {
        let result = AppLogger.data.measure("test") { 42 }
        #expect(result == 42)
    }

    @Test func rethrowsTheBodysError() {
        #expect(throws: Boom.self) {
            try AppLogger.data.measure("test") { throw Boom() }
        }
    }

    @Test func runsTheBodyExactlyOnce() {
        var calls = 0
        _ = AppLogger.data.measure("test") { calls += 1 }
        #expect(calls == 1)
    }

    @Test func returnsTheBodysValueWhenAsync() async {
        let result = await AppLogger.data.measure("test") { 42 }
        #expect(result == 42)
    }

    @Test func rethrowsTheBodysErrorWhenAsync() async {
        await #expect(throws: Boom.self) {
            try await AppLogger.data.measure("test") { throw Boom() }
        }
    }

    @Test func runsTheAsyncBodyExactlyOnce() async {
        var calls = 0
        _ = await AppLogger.data.measure("test") { calls += 1 }
        #expect(calls == 1)
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./Scripts/typecheck.sh`

Expected: FAIL with `value of type 'Logger' has no member 'measure'`.

- [ ] **Step 3: Create `Logger+Measure.swift`**

```swift
//
//  Logger+Measure.swift
//  AppTemplate
//

import Foundation
import os

// Times an operation and leaves both a signpost interval, for Instruments, and
// a duration line, for the console.
//
// `name` is `StaticString` because `OSSignposter.beginInterval` requires one.
// That rules out a dynamic label such as an interpolated URL; put anything
// dynamic in the surrounding log line instead.
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
            notice("\(name, privacy: .public) took \(ms, privacy: .public)ms")
        } else {
            debug("\(name, privacy: .public) took \(ms, privacy: .public)ms")
        }
    }
}
```

The `defer` is what makes a throwing body still close its interval and still log.

- [ ] **Step 4: Verify**

Run: `./Scripts/typecheck.sh`

Expected: `Typechecking 114 files...` then `Clean.`

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Core/Observability/Logger+Measure.swift \
        AppTemplateTests/LoggerMeasureTests.swift
git commit -m "[main] Add measure for timing an operation"
git log -1 --format=%B
```

---

### Task 3: `MainThreadWatchdog`

**Files:**
- Create: `AppTemplate/Core/Observability/MainThreadWatchdog.swift`
- Test: `AppTemplateTests/MainThreadWatchdogTests.swift`

**Interfaces:**
- Consumes: `DiagnosticsDefaults.mainThreadStall`, `.watchdogPoll`, `Duration.milliseconds`, `Duration.timeInterval` from Task 1.
- Produces: `MainThreadWatchdog(threshold:poll:onStall:)`, `@MainActor func start()`, `@MainActor func stop()`.

- [ ] **Step 1: Write the failing test**

Create `AppTemplateTests/MainThreadWatchdogTests.swift`. The suite is `.serialized` because each test deliberately blocks the main thread, and a parallel sibling would be blocked too and report a false stall.

```swift
//
//  MainThreadWatchdogTests.swift
//  AppTemplateTests
//

import Foundation
import os
import Testing
@testable import AppTemplate

@Suite(.serialized)
struct MainThreadWatchdogTests {

    /// Collects stalls from the watchdog's background queue.
    private final class Recorder: @unchecked Sendable {
        private let stalls = OSAllocatedUnfairLock(initialState: [Duration]())
        var recorded: [Duration] { stalls.withLock { $0 } }
        func record(_ stall: Duration) { stalls.withLock { $0.append(stall) } }
    }

    @MainActor
    @Test func reportsAStalledMainThread() async {
        let recorder = Recorder()
        let watchdog = MainThreadWatchdog(
            threshold: .milliseconds(100),
            poll: .milliseconds(20),
            isEnabled: true,
            onStall: { recorder.record($0) }
        )
        watchdog.start()
        defer { watchdog.stop() }

        // Let the first ping go out and be answered, then block on purpose.
        try? await Task.sleep(for: .milliseconds(60))
        Thread.sleep(forTimeInterval: 0.4)
        try? await Task.sleep(for: .milliseconds(120))

        let recorded = recorder.recorded
        #expect(recorded.count == 1, "a single stall must report once, not once per poll")
        #expect(recorded.first ?? .zero >= .milliseconds(100))
    }

    @MainActor
    @Test func staysQuietWhenTheMainThreadIsResponsive() async {
        let recorder = Recorder()
        let watchdog = MainThreadWatchdog(
            threshold: .milliseconds(100),
            poll: .milliseconds(20),
            isEnabled: true,
            onStall: { recorder.record($0) }
        )
        watchdog.start()
        defer { watchdog.stop() }

        // Yield repeatedly so the main queue keeps draining.
        for _ in 0..<20 { try? await Task.sleep(for: .milliseconds(20)) }

        #expect(recorder.recorded.isEmpty)
    }

    @MainActor
    @Test func stopEndsReporting() async {
        let recorder = Recorder()
        let watchdog = MainThreadWatchdog(
            threshold: .milliseconds(100),
            poll: .milliseconds(20),
            isEnabled: true,
            onStall: { recorder.record($0) }
        )
        watchdog.start()
        try? await Task.sleep(for: .milliseconds(60))
        watchdog.stop()

        Thread.sleep(forTimeInterval: 0.4)
        try? await Task.sleep(for: .milliseconds(120))

        #expect(recorder.recorded.isEmpty)
    }
}
```

Note: these tests pass `isEnabled: true` so they run regardless of the build's `API_LOGGING_ENABLED`, and an explicit `onStall` so they assert without parsing console output.

- [ ] **Step 2: Run it to verify it fails**

Run: `./Scripts/typecheck.sh`

Expected: FAIL with `cannot find 'MainThreadWatchdog' in scope`.

- [ ] **Step 3: Create `MainThreadWatchdog.swift`**

```swift
//
//  MainThreadWatchdog.swift
//  AppTemplate
//

import Foundation
import os

// Reports when the main queue stops draining, by ping and pong: a background
// timer stamps a time and dispatches a block to the main queue to clear it. A
// later tick finding the stamp uncleared means the queue has not drained.
//
// Simpler than a CFRunLoopObserver and it measures the thing that matters.
final class MainThreadWatchdog: @unchecked Sendable {

    private struct Ping {
        var sentAt: ContinuousClock.Instant?
        var hasReported = false
    }

    private let threshold: Duration
    private let poll: Duration
    private let isEnabled: Bool
    private let onStall: @Sendable (Duration) -> Void

    private let ping = OSAllocatedUnfairLock(initialState: Ping())
    private let queue = DispatchQueue(label: "diagnostics.watchdog")

    // Only touched from `start` and `stop`, both main-actor isolated.
    @MainActor private var timer: DispatchSourceTimer?

    // `isEnabled` follows LoggingInterceptor's pattern exactly, which is how
    // everything else in this codebase takes that flag while staying testable.
    init(
        threshold: Duration = DiagnosticsDefaults.mainThreadStall,
        poll: Duration = DiagnosticsDefaults.watchdogPoll,
        isEnabled: Bool = APIConfig.isLoggingEnabled,
        onStall: @escaping @Sendable (Duration) -> Void = MainThreadWatchdog.log
    ) {
        self.threshold = threshold
        self.poll = poll
        self.isEnabled = isEnabled
        self.onStall = onStall
    }

    static let log: @Sendable (Duration) -> Void = { stalled in
        AppLogger.lifecycle.notice(
            "Main thread blocked for at least \(stalled.milliseconds, privacy: .public)ms"
        )
    }

    @MainActor
    func start() {
        guard isEnabled, timer == nil else { return }

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + poll.timeInterval, repeating: poll.timeInterval)
        source.setEventHandler { [weak self] in self?.tick() }
        source.resume()
        timer = source
    }

    @MainActor
    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        let stall: Duration? = ping.withLock { ping in
            guard let sentAt = ping.sentAt else {
                ping.sentAt = ContinuousClock.now
                ping.hasReported = false
                return nil
            }

            let elapsed = ContinuousClock.now - sentAt
            guard elapsed >= threshold, !ping.hasReported else { return nil }
            ping.hasReported = true
            return elapsed
        }

        if let stall {
            onStall(stall)
            return
        }

        // Outside the lock: never dispatch while holding it.
        DispatchQueue.main.async { [ping] in
            ping.withLock { $0.sentAt = nil }
        }
    }
}
```

- [ ] **Step 4: Verify**

Run: `./Scripts/typecheck.sh`

Expected: `Typechecking 116 files...` then `Clean.`

- [ ] **Step 5: Commit**

```bash
git add AppTemplate/Core/Observability/MainThreadWatchdog.swift \
        AppTemplateTests/MainThreadWatchdogTests.swift
git commit -m "[main] Add a main thread watchdog"
git log -1 --format=%B
```

---

### Task 4: Wire the performance pieces in

Nothing so far runs on its own. This starts the watchdog and puts `measure` at the three async choke points the template owns, so an app built on it benefits with no work.

**Files:**
- Modify: `AppTemplate/Core/Observability/Observability.swift`
- Modify: `AppTemplate/Core/Networking/APIClient.swift:122`
- Modify: `AppTemplate/Core/Images/ImageLoader.swift:70`
- Modify: `AppTemplate/Core/Session/TokenRefreshCoordinator.swift:33`

**Interfaces:**
- Consumes: `Logger.measure` from Task 2, `MainThreadWatchdog` from Task 3.
- Produces: no new API.

- [ ] **Step 1: Start the watchdog from `install`**

In `AppTemplate/Core/Observability/Observability.swift`, add the property and one line, matching how `Breadcrumb` is already installed:

```swift
    private static let watchdog = MainThreadWatchdog()

    static func install(analytics: any AnalyticsTracking, crashes: any CrashReporting) {
        Self.analytics = analytics
        Self.crashes = crashes
        Breadcrumb.install(crashes)
        watchdog.start()
    }
```

`Observability` is already `@MainActor`, so `start()` is callable directly.

- [ ] **Step 2: Measure a whole request**

In `AppTemplate/Core/Networking/APIClient.swift`, wrap the body of `perform`. `perform` is chosen over `attemptOnce` deliberately: one interval per logical request means the log reads "this call took 4.2s across 3 attempts" rather than three unrelated intervals.

Change the declaration line and wrap the existing body, leaving every line inside it untouched:

```swift
    private func perform(_ endpoint: Endpoint) async throws -> Data {
        try await AppLogger.network.measure("request") {
            try await self.performOnce(endpoint)
        }
    }

    private func performOnce(_ endpoint: Endpoint) async throws -> Data {
        var attempt = 0
        var interceptorRetries = 0

        while true {
```

The rest of the original `perform` body becomes `performOnce` unchanged. Do not alter the retry loop, the recovery decision, or any error path.

- [ ] **Step 3: Measure an image load**

In `AppTemplate/Core/Images/ImageLoader.swift`, wrap the body of `image(for:)` the same way, renaming the original to `loadImage(for:)`:

```swift
    func image(for url: URL) async throws -> UIImage {
        try await AppLogger.images.measure("image load") {
            try await self.loadImage(for: url)
        }
    }

    private func loadImage(for url: URL) async throws -> UIImage {
```

Leave the original body, including the in-flight deduplication and the cache writes, exactly as it is.

- [ ] **Step 4: Measure a token refresh**

In `AppTemplate/Core/Session/TokenRefreshCoordinator.swift`, wrap `refresh(staleAccessToken:)` the same way:

```swift
    func refresh(staleAccessToken: String?) async throws -> AuthTokens {
        try await AppLogger.auth.measure("token refresh") {
            try await self.performRefresh(staleAccessToken: staleAccessToken)
        }
    }

    private func performRefresh(staleAccessToken: String?) async throws -> AuthTokens {
```

Leave the single-flighting, the in-flight task reuse and the invalidation path untouched. This is the one latency on the critical path of every 401 and it is invisible today.

- [ ] **Step 5: Verify**

Run: `./Scripts/typecheck.sh`

Expected: `Typechecking 116 files...` then `Clean.`

Run: `grep -c 'measure(' AppTemplate/Core/Networking/APIClient.swift AppTemplate/Core/Images/ImageLoader.swift AppTemplate/Core/Session/TokenRefreshCoordinator.swift`

Expected: `1` for each.

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/Core/Observability/Observability.swift \
        AppTemplate/Core/Networking/APIClient.swift \
        AppTemplate/Core/Images/ImageLoader.swift \
        AppTemplate/Core/Session/TokenRefreshCoordinator.swift
git commit -m "[main] Time requests, image loads and token refreshes"
git log -1 --format=%B
```

---

### Task 5: `ReportableError` and the reporting funnel

**Files:**
- Create: `AppTemplate/Core/Observability/Diagnostics.swift`
- Modify: `AppTemplate/Core/Testing/Mocks.swift`
- Test: `AppTemplateTests/DiagnosticsTests.swift`

**Interfaces:**
- Consumes: `Observability.crashes`, `Breadcrumb.record`, both existing.
- Produces: `protocol ReportableError: Error { var isWorthReporting: Bool { get } }` with a `true` default; `@MainActor Diagnostics.report(_ error: any Error, context: String)`; `MockCrashReporter` with `recorded: [any Error]`, `logged: [String]`, `userIDs: [String?]`.

- [ ] **Step 1: Add the mock**

`Core/Testing/Mocks.swift` is wrapped in `#if DEVELOPMENT`. Add inside that block, beside the existing repository mocks:

```swift
final class MockCrashReporter: CrashReporting, @unchecked Sendable {

    private let state = OSAllocatedUnfairLock(initialState: State())

    private struct State {
        var recorded: [any Error] = []
        var logged: [String] = []
        var userIDs: [String?] = []
    }

    var recorded: [any Error] { state.withLock { $0.recorded } }
    var logged: [String] { state.withLock { $0.logged } }
    var userIDs: [String?] { state.withLock { $0.userIDs } }

    func record(_ error: Error) { state.withLock { $0.recorded.append(error) } }
    func log(_ message: String) { state.withLock { $0.logged.append(message) } }
    func setUser(id: String?) { state.withLock { $0.userIDs.append(id) } }
}
```

Add `import os` to that file if it is not already imported.

- [ ] **Step 2: Write the failing test**

Create `AppTemplateTests/DiagnosticsTests.swift`. The suite is `.serialized` because every test installs into the shared `Observability.crashes`.

```swift
//
//  DiagnosticsTests.swift
//  AppTemplateTests
//

import Foundation
import Testing
@testable import AppTemplate

@Suite(.serialized)
@MainActor
struct DiagnosticsTests {

    private struct Unclassified: Error {}

    private struct Quiet: ReportableError {
        var isWorthReporting: Bool { false }
    }

    private struct Loud: ReportableError {
        var isWorthReporting: Bool { true }
    }

    private func withReporter(_ body: (MockCrashReporter) -> Void) {
        let previous = Observability.crashes
        let mock = MockCrashReporter()
        Observability.crashes = mock
        Breadcrumb.install(mock)
        defer {
            Observability.crashes = previous
            Breadcrumb.install(previous)
        }
        body(mock)
    }

    @Test func reportsAnErrorThatIsWorthReporting() {
        withReporter { mock in
            Diagnostics.report(Loud(), context: "Saving")
            #expect(mock.recorded.count == 1)
        }
    }

    @Test func doesNotReportAnErrorThatIsNotWorthReporting() {
        withReporter { mock in
            Diagnostics.report(Quiet(), context: "Saving")
            #expect(mock.recorded.isEmpty)
        }
    }

    @Test func breadcrumbsEvenWhenItDoesNotReport() {
        withReporter { mock in
            Diagnostics.report(Quiet(), context: "Saving")
            #expect(mock.logged.count == 1)
            #expect(mock.logged.first?.hasPrefix("Saving: ") == true)
        }
    }

    @Test func reportsAnUnclassifiedErrorByDefault() {
        withReporter { mock in
            // An error nobody classified is likelier a defect than an expected
            // condition, so silence must be opted into.
            Diagnostics.report(Unclassified(), context: "Saving")
            #expect(mock.recorded.count == 1)
        }
    }

    @Test func conformanceDefaultsToReporting() {
        struct Bare: ReportableError {}
        #expect(Bare().isWorthReporting)
    }
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `./Scripts/typecheck.sh`

Expected: FAIL with `cannot find type 'ReportableError' in scope` and `cannot find 'Diagnostics' in scope`.

- [ ] **Step 4: Create `Diagnostics.swift`**

```swift
//
//  Diagnostics.swift
//  AppTemplate
//

import Foundation

// Anything thrown that is worth a non-fatal. The default is `true` because an
// error nobody has classified is likelier a defect than an expected condition,
// so staying quiet has to be opted into.
protocol ReportableError: Error {
    var isWorthReporting: Bool { get }
}

extension ReportableError {
    var isWorthReporting: Bool { true }
}

@MainActor
enum Diagnostics {

    /// One funnel for any error, network or not. Breadcrumbs everything and
    /// reports what is worth reporting.
    static func report(_ error: any Error, context: String) {
        Breadcrumb.record("\(context): \(error)")

        let isWorthReporting = (error as? any ReportableError)?.isWorthReporting ?? true
        if isWorthReporting {
            Observability.crashes.record(error)
        }
    }
}
```

- [ ] **Step 5: Verify**

Run: `./Scripts/typecheck.sh`

Expected: `Typechecking 118 files...` then `Clean.`

- [ ] **Step 6: Commit**

```bash
git add AppTemplate/Core/Observability/Diagnostics.swift \
        AppTemplate/Core/Testing/Mocks.swift \
        AppTemplateTests/DiagnosticsTests.swift
git commit -m "[main] Add one reporting funnel for any error"
git log -1 --format=%B
```

---

### Task 6: Report errors that are not network errors

The gap this whole plan exists for. `KeychainError` and `ImageLoaderError` are thrown and logged today and reach Crashlytics never, because `APIError.classify` is the only funnel and it only understands `APIError`.

**Files:**
- Modify: `AppTemplate/Core/Networking/APIError.swift:195-205, 233-239`
- Modify: `AppTemplate/Core/Storage/TokenStore.swift:11-22`
- Modify: `AppTemplate/Core/Images/ImageLoader.swift:20-23, 108-111`
- Modify: `AppTemplate/Core/Session/SessionManager.swift:93-96`
- Modify: `AppTemplate/Core/Images/CachedAsyncImage.swift:41`
- Modify: `AppTemplate/Core/Networking/Interceptors/AuthInterceptor.swift:24`
- Test: `AppTemplateTests/ReportableErrorTests.swift`

**Interfaces:**
- Consumes: `ReportableError`, `Diagnostics.report` from Task 5.
- Produces: conformances only.

- [ ] **Step 1: Write the failing test**

Create `AppTemplateTests/ReportableErrorTests.swift`:

```swift
//
//  ReportableErrorTests.swift
//  AppTemplateTests
//

import Foundation
import Testing
@testable import AppTemplate

struct ReportableErrorTests {

    @Test func keychainFailuresAlwaysReport() {
        // errSecItemNotFound is handled without throwing, so anything that
        // escapes the store is unexpected.
        #expect(KeychainError.unhandled(status: -25299).isWorthReporting)
    }

    @Test func undecodableImageBytesReport() {
        #expect(ImageLoaderError.invalidImageData.isWorthReporting)
    }

    @Test func aMissingImageDoesNotReport() {
        // Content problem, not a defect.
        #expect(!ImageLoaderError.httpStatus(404).isWorthReporting)
    }

    @Test func aServerErrorOnAnImageReports() {
        #expect(ImageLoaderError.httpStatus(500).isWorthReporting)
    }

    @Test func apiErrorKeepsItsExistingFilter() {
        // Unchanged behaviour, pinned so the conformance cannot drift.
        #expect(APIError.decodingFailed(detail: "x").isWorthReporting)
        #expect(APIError.server(status: 503).isWorthReporting)
        #expect(!APIError.notFound().isWorthReporting)
        #expect(!APIError.offline.isWorthReporting)
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./Scripts/typecheck.sh`

Expected: FAIL with `value of type 'KeychainError' has no member 'isWorthReporting'`.

- [ ] **Step 3: Conform `APIError`, changing nothing about it**

In `AppTemplate/Core/Networking/APIError.swift`, add the conformance to the existing declaration. `isWorthReporting` already exists with the right signature, so the protocol is satisfied with no new code:

```swift
extension APIError: ReportableError {}
```

Then have `classify` delegate, which preserves both the breadcrumb text and the filter exactly:

```swift
    /// One funnel for every catch block: types the error and reports the broken ones.
    @MainActor
    static func classify(_ error: any Error) -> APIError {
        let apiError = error as? APIError ?? .from(transportError: error)
        Diagnostics.report(apiError, context: "Request failed")
        return apiError
    }
```

- [ ] **Step 4: Conform `KeychainError`**

In `AppTemplate/Core/Storage/TokenStore.swift`, change the declaration:

```swift
enum KeychainError: LocalizedError, Equatable, ReportableError {
    case unhandled(status: OSStatus)
```

It takes the protocol's `true` default. No property is added.

- [ ] **Step 5: Conform `ImageLoaderError` and report at its throw site**

In `AppTemplate/Core/Images/ImageLoader.swift`, add the conformance:

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

Then report from the catch inside `loadImage(for:)`, which currently clears the in-flight entry and rethrows:

```swift
        } catch {
            inFlight[url] = nil
            await Diagnostics.report(error, context: "Loading an image")
            throw error
        }
```

`await` is required: `ImageLoader` is an actor and `Diagnostics.report` is main-actor isolated.

- [ ] **Step 6: Fix the one swallow that matters**

In `AppTemplate/Core/Session/SessionManager.swift`, `refreshCurrentUser` discards the error entirely, leaving a half-signed-in state with nothing recorded:

```swift
    func refreshCurrentUser() async {
        guard state == .authenticated else { return }

        do {
            setCurrentUser(try await users.currentUser())
        } catch {
            // Tolerated: the session stays valid and the cached user stands.
            // Reported, because a profile fetch failing is not expected.
            Diagnostics.report(error, context: "Refreshing the current user")
        }
    }
```

Behaviour is preserved: a failure still does not sign the user out. It is now visible.

- [ ] **Step 7: Document the two silences that are correct**

In `AppTemplate/Core/Images/CachedAsyncImage.swift`:

```swift
        // Deliberately silent: a placeholder is the right outcome for a view,
        // and ImageLoader has already reported the failure at its throw site.
        if let uiImage = try? await loader.image(for: url) {
```

In `AppTemplate/Core/Networking/Interceptors/AuthInterceptor.swift`:

```swift
        if let current = tokens, current.needsProactiveRefresh, current.canRefresh {
            // Deliberately silent: TokenRefreshCoordinator reports its own
            // failure, and a proactive refresh that fails falls through to the
            // existing token rather than failing the request.
            tokens = try? await coordinator.refresh(staleAccessToken: current.accessToken)
        }
```

- [ ] **Step 8: Verify**

Run: `./Scripts/typecheck.sh`

Expected: `Typechecking 119 files...` then `Clean.`

Run: `grep -rn 'Observability.crashes.record' AppTemplate --include='*.swift'`

Expected: one hit, inside `Diagnostics.swift`. Every other reporting path now goes through the funnel.

- [ ] **Step 9: Commit**

```bash
git add AppTemplate/Core/Networking/APIError.swift \
        AppTemplate/Core/Storage/TokenStore.swift \
        AppTemplate/Core/Images/ImageLoader.swift \
        AppTemplate/Core/Images/CachedAsyncImage.swift \
        AppTemplate/Core/Session/SessionManager.swift \
        AppTemplate/Core/Networking/Interceptors/AuthInterceptor.swift \
        AppTemplateTests/ReportableErrorTests.swift
git commit -m "[main] Report Keychain and image failures, not just network ones"
git log -1 --format=%B
```

---

### Task 7: Document it and sweep

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing code-facing.

- [ ] **Step 1: Add a Diagnostics section to the README**

Place it after the Firebase section. Do not overstate what this gives you:

```markdown
## Diagnostics

Development builds log what they are doing and shout when something stalls. All
of it is gated on `API_LOGGING_ENABLED`, so Staging and Production pay nothing.

`AppLogger.<category>.measure("name") { ... }` times an operation, logging at
`.debug` normally and `.notice` past 100ms, and emits a signpost interval either
way. Requests, image loads and token refreshes are already wrapped, so a slow
call shows up without any work.

A main thread watchdog reports when the main queue stops draining for 250ms or
more:

    Main thread blocked for at least 412.0ms

Read it live with:

```bash
xcrun simctl spawn booted log stream --predicate 'subsystem CONTAINS "AppTemplate"' --level debug
```

**This is detection, not diagnosis.** It tells you *that* something is wrong so
you know to open Instruments, which tells you *why*. Call stacks, retain cycles
and allocation attribution cannot be logged. Signposts are never gated, so they
still show up in Instruments' Points of Interest track when you profile a
Staging build.

For production, MetricKit is the counterpart: it reports hangs with call stacks
from real devices, roughly daily. It is not wired here, deliberately, since it
is useless at a desk and has no dashboard of its own.

### Error reporting

Every thrown error should reach Crashlytics through one funnel:

```swift
Diagnostics.report(error, context: "Saving the draft")
```

It breadcrumbs everything and records a non-fatal when the error is worth one.
Conform an error to `ReportableError` to control that; the default is to report,
so staying quiet is opted into:

```swift
extension MyError: ReportableError {
    var isWorthReporting: Bool {
        switch self {
        case .diskFull: true
        case .userCancelled: false
        }
    }
}
```

`APIError`, `KeychainError` and `ImageLoaderError` already conform.
```

- [ ] **Step 2: Sweep**

Run each and expect no output:

```bash
grep -rnP '\x{2014}' AppTemplate AppTemplateTests Scripts README.md docs
git log --format=%B origin/main..HEAD | grep -ci 'co-authored-by\|generated with'
```

The second must print `0`.

Confirm the funnel is the only reporting path:

```bash
grep -rn 'crashes.record' AppTemplate --include='*.swift' | grep -v 'Diagnostics.swift' | grep -v 'func record'
```

Expected: no output apart from `FirebaseObservability.swift`, which is the adapter that implements `record`.

- [ ] **Step 3: Final typecheck**

Run: `./Scripts/typecheck.sh`

Expected: `Typechecking 119 files...` then `Clean.`, with only the pre-existing `ImagePicker.swift` warning.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "[main] Document diagnostics and error reporting"
git log -1 --format=%B
```

- [ ] **Step 5: Hand back to the user**

The test suite has not been run; agents cannot run it. Report the branch state and give the user:

```bash
cd /Users/patrick/Projects/AppTemplate && xcodebuild test -scheme Development -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Say plainly that the suite has not been run and that the typecheck is not a substitute for it.

---

## Open items this plan does not close

- `ImagePicker.swift:21` has a pre-existing `SendableMetatypes` warning about capturing `Label.Type` in an isolated closure. It predates this work and is left alone.
- Analytics coverage stays at six events. Widening it is an app concern, not a template one.
- MetricKit is deliberately absent. It is the production counterpart to the watchdog and deserves its own spec once an app built on this template ships.
