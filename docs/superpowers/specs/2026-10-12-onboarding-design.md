# Onboarding: design

## Purpose

The template is copied as a reference base for new apps. Onboarding is a first-run flow that
new projects inherit, so its structure must be generic and easy to replace, with no product
copy or palette baked in.

## Scope

- Three onboarding pages shown once per install, before sign-in.
- Skippable from every page.
- Gate runs for every user, including one whose Keychain session survived a reinstall.

Out of scope: a per-account flag, analytics events, animation polish, and any backend change.

## Routing

`SessionManager.State` gains an `.onboarding` case.

`bootstrap()` resolves the auth outcome exactly as it does today. If onboarding has not been
seen, it parks the session at `.onboarding` and records the outcome it resolved. Completing
onboarding marks it seen and moves to that recorded outcome: `.authenticated` or
`.unauthenticated`.

The gate runs before the auth outcome is applied, so a reinstalled user with a restored session
still sees onboarding once. This keeps the once-per-install rule literally true.

`RootView` gains one branch: `.onboarding` shows `OnboardingView`. Its other cases are unchanged.

## Components

- `OnboardingStoring`: protocol with `hasSeen: Bool` and `markSeen()`.
- `UserDefaultsOnboardingStore`: the live implementation, injected through `AppDependencies` the
  way `TokenStore` is. Tests use an in-memory double.
- `OnboardingPage`: value type holding an SF Symbol name, a title and a body. Three generic
  pages, no product artwork.
- `OnboardingViewModel`: owns the current index, `next()`, `skip()` and `isLastPage`, and
  reports completion through a callback. It holds no view code.
- `OnboardingView`: paged view with Skip on every page and Get Started on the last. Built from
  existing `Theme` tokens.

## Deep links

Onboarding does not touch `AppNavigator`. A password-reset link opened on a fresh install stays
pending and applies after sign-in, as it does today. This is covered by a test, because it is
the failure this placement could cause.

## Strings

All copy lives in `Localizable.xcstrings` with a comment on every entry. The copy stays generic
so a copied project replaces it without working around product language.

## Testing

- `OnboardingViewModelTests`: paging, skip marks seen, finish marks seen, and the last page
  reports `isLastPage`.
- `SessionManagerTests`:
  - fresh install with no token: onboarding, then unauthenticated;
  - fresh install with a token: onboarding, then authenticated;
  - already seen: behaviour identical to today.
- A pending deep link survives onboarding.

Views stay untested, per the template's convention.
