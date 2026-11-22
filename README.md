# AppTemplate

A production-ready SwiftUI app template. MVVM + Repository, Swift 6 strict concurrency, a complete auth lifecycle, and no third-party runtime dependencies - everything below is Apple frameworks only.

- iOS 17+ · Swift 6 · Xcode 26

## Getting started

Clone, rename, and you have a running app in under ten minutes.

### 1. Clone and rename

Three commands. Substitute your own values.

```bash
git clone <this-repo> MyApp
cd MyApp
Scripts/rename.sh MyApp com.acmecorp "My App"
```

The three arguments to the script:

| | | |
|---|---|---|
| `MyApp` | required | The app name. Becomes the target, the source folder, and a Swift type, so it takes letters and digits only, starting with a letter - no spaces or hyphens. |
| `com.acmecorp` | required | Your bundle prefix. Lowercase reverse-DNS, at least two components. |
| `"My App"` | optional | The home screen name, quoted because it can contain spaces. Leave it off when it matches the app name - `Scripts/rename.sh Runly com.acmecorp` gives an app called Runly. |

This renames the project, target, schemes, source folder, app entry point, and every file header, and rewrites the bundle IDs, display names, and deep link scheme. It needs a clean working tree, so `git checkout . && git clean -fd` undoes any run.

### 2. Start your own history

```bash
rm -rf .git && git init && git add -A && git commit -m "Initial commit"
```

### 3. Finish the setup

The app builds and runs as-is. Two things the script can't do for you, plus one decision.

- **Your API** - set `API_BASE_URL` in each of the three `Config/*.xcconfig`
- **App icon and colours** - all ship empty. See [Branding](#branding)
- **Analytics** - *none ships*. There is no analytics or crash-reporting SDK. See [Observability](#observability) for where to add one.

```bash
xcodebuild -scheme Development -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Removing the sample

`Item` is a worked example, not something to build on. Keep it while you write your first real feature - it's the only place pagination, `LoadState`, and the repository pattern are shown working end to end - then delete it.

```
Features/Main/HomeView/               the list screen
Data/ItemRepository.swift
Models/Models.swift                   the Item and ItemDraft types
Core/Testing/Mocks.swift              SampleData.items and MockItemRepository
```

Then remove `makeHomeViewModel` and the `items` property from `AppDependencies`. The compiler finds anything you miss.

`HomeView` is the root of the signed-in stack, so put your own screen in its place in `MainFlowView` rather than leaving the root empty.

## What's inside

- **Networking** - one send path with verb helpers, typed errors, server-message parsing, interceptors, retry with backoff
- **Auth** - access + refresh tokens, single-flight refresh, 401 to refresh to retry to sign-out, Keychain storage
- **Navigation** - typed routes, deep links, universal links, deferred links, force-update and maintenance gates
- **UI** - design system, unified `LoadState`, empty / error / skeleton states, accessibility identifiers, localization via String Catalog
- **Images** - bounded two-tier cache with LRU eviction and in-flight de-duplication
- **Connectivity** - `NWPathMonitor` behind an offline banner, so a failing screen reads as a connection problem
- **Logging** - `AppLogger` over `OSLog`, one category per area; every request failure funnels through `APIError.classify`
- **Build** - three environments, privacy manifest, one-command rename

The service gates are driven by HTTP status, not by a version endpoint. A `426` blocks the app behind "Update Required" and a `503` behind "Back Soon", both routed through `SessionEventBus`. `APIConfig.isForceUpdateEnabled` and the `VersionCheck` model belong to a client-side version-comparison approach that isn't built - delete them, or wire them to a version endpoint if you prefer that shape.

Deliberately **not** included - analytics, crash reporting, and push notifications. See [Observability](#observability) and [Push is not wired](#push-is-not-wired).

## Architecture

```
View (SwiftUI, no logic)
  ↕ @Observable
ViewModel (@MainActor, owns LoadState)
  ↕ protocol
Repository (maps API to models)
  ↕ protocol
APIClient (one send path + interceptors)
```

Each layer depends on the protocol below it. `AppDependencies` is the one place concrete types meet, which is what makes it testable and swappable.

## Branding

Everything you replace per project lives in `AppTemplate/Assets.xcassets`. All three ship empty.

### App icon

Open `Assets.xcassets` -> `AppIcon` and drag a PNG onto each well. There are three 1024x1024 slots:

| Slot | Used when |
|---|---|
| **Any Appearance** | Always. The only one that is required. |
| **Dark** | Home screen in dark mode |
| **Tinted** | Home screen with a tint applied |

Fill the first and iOS derives the other two. Fill all three when you want control over each.

**Rules Apple enforces:**

- **1024 x 1024**, square
- **No alpha channel.** Transparency is rejected at upload with `ITMS-90717`, and iOS composites it against black. Check yours with `sips -g hasAlpha icon.png`
- **Edge to edge**, no padding of your own. iOS applies a rounded mask that crops the corners, so keep important detail inside the middle 80%
- **No rounded corners, no shadows.** iOS adds those

The icon renders at 60 x 60 pt on the home screen, about 17x smaller than the file. A small mark floating in empty space disappears at that size.

### Accent colour

`AccentColor` has no value set, so SwiftUI falls back to system blue. Give it **Any** and **Dark** appearances in the asset catalog.

Everything that reads `Theme.Color.accent` picks it up - buttons, links, control tints.

### Launch background

`LaunchBackground` is used by `RootView` while the session is bootstrapping, and by `PrivacyShieldView` in the app switcher.

It does **not** set the system launch screen, which is currently the default background. To match them and remove the flash on launch, add this to `Config/Shared.xcconfig`:

```
INFOPLIST_KEY_UILaunchScreen_BackgroundColor = LaunchBackground
```

## Environments

Three configs, one shared base. All install side by side on one device.

| | Development | Staging | Production |
|---|---|---|---|
| Bundle ID | `.dev` | `.staging` | *(none)* |
| Request logging | on | off | off |

Values live in `Config/*.xcconfig` and reach code through `APIConfig`. Never hardcode a URL.

## Secrets

Client SDK keys you'd rather not publish go in `Config/Secrets.xcconfig`, which is gitignored. Copy `Secrets.example.xcconfig`, drop the `.example`, fill it in - all three environments already `#include?` it, and the `?` means a clone without the file still builds.

Everything there is substituted into Info.plist and ships inside the IPA. It keeps values out of git, not off a device. Server-side keys belong on your server.

## Hardening

Four opt-in protections. Two of them - jailbreak and anti-debug - are heuristic and report-only by design, so they flag rather than block.

> **Pinning is optional.** The app is fully safe and behaves like a normal HTTPS app while `PINNED_PUBLIC_KEY_HASHES` is left blank - an empty list means default TLS trust, no extra rules. You only need to fill it in once you have a real production backend and want the extra protection.

### Certificate pinning

Pins the server's **public key** (SPKI), not the certificate, so a certificate renewal with the same key doesn't break the app.

`CERT_PINNING_ENABLED = NO` in all three configs, because there is no backend to pin against yet. Keep it off in Development and Staging even after you have one, so local proxies (Charles, Proxyman) and self-signed certs still work. Turn it on in Production only once `PINNED_PUBLIC_KEY_HASHES` has real values - enabling it with an empty list claims pinning while performing none.

1. Generate the base64 SPKI hash for each endpoint's leaf certificate:

   ```bash
   openssl s_client -connect api.example.com:443 -showcerts </dev/null 2>/dev/null \
     | openssl x509 -pubkey -noout \
     | openssl pkey -pubin -outform der \
     | openssl dgst -sha256 -binary \
     | base64
   ```

2. Paste the output into `PINNED_PUBLIC_KEY_HASHES` in `Config/Production.xcconfig`, comma-separated for multiple keys.

The pinner compares that to the hash the running app computes from the server's presented certificate. Leave the list empty and it falls back to default TLS trust - a safe no-op until you add real hashes. A failed match surfaces as a `.serverTrustFailed` error.

### Screen-capture / app-switcher privacy

A `PrivacyShieldView` covers the UI whenever the app is not active, so the task-switcher snapshot is blank. iOS can't prevent screenshots, so instead the app detects them (`ScreenshotDetector`) and writes a line to `AppLogger.security` - capture is observable, not blockable.

### Jailbreak detection

`JailbreakDetector` checks for the usual filesystem indicators (Cydia, Sileo, sshd, …). It is **report-only**: jailbreak checks are trivially bypassable and can false-positive, so the app logs the device to `AppLogger.security` rather than refusing to run.

### Anti-debug

`DebuggerDetector` reads the `P_TRACED` process flag via `sysctl` and reports an attached debugger. Deliberately no `ptrace(PT_DENY_ATTACH)` - that reads as anti-tampering to App Review and can get a submission rejected. Obfuscation beyond the existing Release symbol-stripping is intentionally not attempted.

## Observability

**Nothing is sent anywhere.** There is no analytics SDK, no crash reporter, and no network telemetry. The app's only instrumentation is `AppLogger`, a thin wrapper over `OSLog` with one category per area (`network`, `auth`, `data`, `images`, `navigation`, `lifecycle`, `security`). Those lines go to Console.app and the device log, and no further.

Two places are worth knowing about.

- `APIError.classify` is the single funnel every `catch` block runs through. It types the error and logs it, loudly when `isWorthReporting` says the app or backend is broken, quietly when the network is just flaky.
- `AppLogger.security` carries the report-only hardening events - jailbreak indicators, an attached debugger, a screenshot. See [Hardening](#hardening).

### Adding a crash reporter or analytics

Nothing in the app knows about a reporter, so there is no seam to fill in and no protocol to conform to. Pick your SDK, call its configure method from `AppDependencies.live()`, and send events from wherever you want them.

If you want the old shape back - a protocol per concern so features never import the SDK - it is two small files: a protocol with the calls you need and a no-op implementation for tests and for builds without a key. Hold the live instance on `AppDependencies` and inject it into the view models that report.

Two things to get right whichever SDK you choose.

- **The privacy manifest.** `PrivacyInfo.xcprivacy` currently declares no tracking and no required-reason APIs beyond the template's own. Most analytics SDKs change both, and Apple validates the manifest against the binary. A mismatch is a rejection.
- **What you log.** `APIError`'s associated values can carry server messages and user input. Send a stable label rather than the error itself if you report failures.

### Push is not wired

`UserRepository` declares `registerForPushNotifications(token:)` and `unregisterForPushNotifications(token:)`. **Nothing calls them.** There is no push SDK and no `MessagingDelegate` anywhere.

To finish it with APNs directly:

- Ask for permission with `UNUserNotificationCenter`, then call `registerForRemoteNotifications()`
- Implement `didRegisterForRemoteNotificationsWithDeviceToken` in `AppDelegate` and pass the token to `registerForPushNotifications(token:)`
- Clear it on sign-out, in `SignOutAction`
- Route taps through `AppNavigator`, which already handles deep links
- Add the **Push Notifications** capability and an APNs key or certificate

That last one needs a paid Apple Developer membership, which is why push stays scaffolded rather than half-implemented.

## Structure

```
AppTemplate/
├── App/              entry point, composition root
├── Components/       reusable inputs, buttons, picker
├── Core/
│   ├── Images/       two-tier image cache
│   ├── Navigation/   typed routes, deep links
│   ├── Networking/   client, endpoints, errors, interceptors
│   ├── Observability/ AppLogger over OSLog
│   ├── Security/     pinning, jailbreak, debugger, screenshots
│   ├── Session/      tokens, refresh, session state
│   └── UI/           LoadState, load and error states
├── Data/             repositories
├── DesignSystem/     theme, accessibility identifiers
├── Features/         one folder per screen
├── Models/           models, pagination
└── Resources/        String Catalog
```

## Apple Developer account

Not needed to build, run, or develop against this template. The simulator needs nothing, and a free Apple ID signs builds onto your own device.

A paid membership is required for exactly two things.

- **Push notifications** - the capability and the APNs `.p8` are both members-only
- **Distribution** - TestFlight and the App Store

Everything else works without one.

## Before you ship

- Real API URLs in all three xcconfigs
- The `Item` sample removed
- Review `PrivacyInfo.xcprivacy` against what your backend stores
- App icon and accent color
