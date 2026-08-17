---
name: playsher-flutter
description: Architecture patterns for the Playsher Flutter customer app in `mobile_app/` — ApiClient/Dio, Riverpod providers, JSON models, GoRouter, secure storage, auth and payment flows. Load before adding a screen, provider, model, route, or API call. For visual/UI work load `playsher-mobile-ui` as well.
---

# Playsher mobile — how this Flutter app is built

Flutter 3.22 · Dart 3.4 · Riverpod 2.5 · GoRouter 14 · Dio 5. 23 screens, 5 bottom-nav
branches, portrait-locked, dark-first with a light theme.

```
lib/main.dart        orientation lock + system UI style + ProviderScope
lib/app.dart         MaterialApp.router — themes + themeMode + routerProvider
lib/router.dart      every GoRoute, the auth redirect, the StatefulShellRoute
lib/core/            api_client · constants · storage · theme · app_colors · animations
lib/models/          plain classes with fromJson factories + listFromJson
lib/providers/       Riverpod providers, one file per feature
lib/screens/         one file per screen
lib/widgets/         reusable UI
```

**Data flows one way:** `ApiClient` → `providers` → `screens` → `widgets`.
A screen never calls `ApiClient` directly; a widget never watches a network provider it
wasn't given (pass data in, or watch in the screen and pass down).

## ApiClient — the single Dio path

`core/api_client.dart` holds one lazily-initialised static `Dio` plus **one static method per
endpoint**, grouped by domain with `// ── Section ──` rules and a `// VERB /path` comment above
each. Add new endpoints there; never construct a `Dio` anywhere else.

- The interceptor attaches `Authorization: Bearer <token>` from `StorageService`, logs
  request/response/error, and on **401** (except `/auth/*` paths) attempts a refresh via a
  *separate* bare Dio, retries the original request, and on failure clears storage and fires
  `onSessionExpired` — which `AuthNotifier` uses to force logout. Don't add a second 401 handler.
- Methods return `Map<String, dynamic>`, normalised to `{'data': raw['data'] ?? …}` so callers
  never see the envelope. Keep that normalisation in `ApiClient`, not in providers.
- The debug `print` logging is intentional for now; if you add logging, match the existing
  format rather than inventing a second one.
- **Stubs**: notifications, coupons, rewards, cities, price filters and dashboard return empty
  literals because the API has no such endpoint. Leave the comment saying so. If you implement
  one, implement the backend endpoint in the same change.

## Models

Plain immutable classes, `const` constructors, a `fromJson` factory, and a static
`listFromJson(List<dynamic>)`. Wire keys are `snake_case`, Dart fields are `camelCase` — the
mapping happens **only** in `fromJson`.

Be defensive exactly where the API is: `ground_model.dart` accepts `images` **or**
`slider_images`, `groundSports` **or** `ground_sports`, and merges `facilities` + `features`
into `amenities`. Keep those fallbacks; they cover older payload shapes still in the DB.
Numbers arriving as strings use `double.tryParse(json['x']?.toString() ?? '')`.

Derived values are getters on the model (`primaryImageUrl`, `avgRating`, `startingPrice`,
`formattedStartingPrice`, `sportNames`), never recomputed in a widget.

## Providers

- **Read-only async data** → `FutureProvider` (`sportsProvider`) or
  `FutureProvider.family` when it takes an argument (`groundDetailProvider`, `slotsProvider`).
- **A `family` argument that is not a primitive needs value equality** — define a small
  immutable query class with `operator ==` and `hashCode` (`GroundFilter`, `SlotQuery`), or the
  provider re-fetches on every rebuild. This is the single easiest bug to introduce here.
- **Mutable session/UI state** → `StateNotifierProvider` with an immutable state class and
  `copyWith` (`AuthNotifier`/`AuthState`).
- Refresh is `ref.invalidate(theProvider(arg))` — with the *same* argument the screen watches.
- Errors: catch `DioException` in the notifier and convert to a human sentence
  (`AuthNotifier._extractError` is the model — it maps 401/422/timeouts and reads
  `data['message']`). Never let a raw exception reach a widget.

## Auth flow

`+91 mobile → POST /auth/send-otp → OTP screen → POST /auth/verify-otp`, which returns either
`{ new_user: true }` (→ `/register` → `complete-registration`) or
`{ access_token, refresh_token, user }`. Tokens go to `flutter_secure_storage` via
`StorageService.saveTokens`; the user JSON goes to secure storage too. Non-secret preferences
(onboarding seen, theme mode, city) use `SharedPreferences`.

`AuthNotifier._loadUser` restores a session only when **both** a real token and user data exist —
it clears stale user data with no token. Keep that guard.

Gating lives **only** in `router.dart`'s `redirect`, which reads `authProvider` and is re-run by
`_AuthRouterNotifier` on every auth change. A screen never redirects on auth itself.

## Routing

`GoRouter` with a `StatefulShellRoute.indexedStack` for the five tabs (`/home`, `/venues`,
`/games`, `/coaching`, `/profile`) — each branch keeps its own stack; tapping the active tab
resets it (`initialLocation: i == shell.currentIndex`).

Detail routes are top-level with path params (`/grounds/:id`, `/bookings/:id`, `/games/:id`);
flow screens take `state.extra` as a typed map. Prefer path params over `extra` for anything
that should survive a deep link — `extra` is null on cold start, so a screen that relies on it
must handle null by redirecting out with `context.pushReplacement`.

## Booking + payment flow

`/grounds/:id` → `/book/:groundId` (date + slot grid, `slotsProvider(SlotQuery(...))`) →
`POST /bookings` → if `payment_method: 'online'`, `POST /payments/razorpay/create-order`,
open the Razorpay sheet, then `POST /payments/razorpay/verify` with the three razorpay fields.

- The **server computes the amount**; never send a price from the app.
- The success/failure/cancel Razorpay callbacks must each resolve to a definite outcome exactly
  once, and reach the result screen with `pushReplacement` — never `push`.
- Guard everything after an `await` with `if (!mounted) return;`.

## Adding a feature — the order

1. Backend endpoint exists and is in Swagger (see `playsher-backend`).
2. `ApiClient` method + `// VERB /path` comment.
3. Model with `fromJson`/`listFromJson` if a new entity.
4. Provider (with a value-equal family key if parameterised).
5. Screen + `GoRoute`.
6. Widgets extracted to `lib/widgets/` if reusable — and follow `playsher-mobile-ui`.

## Checklist

- `flutter analyze` clean.
- No `Dio`/`http` outside `ApiClient`; no `ApiClient` call inside a screen.
- Family provider keys have `==`/`hashCode`.
- Loading/empty/error handled for every `.when`.
- No hardcoded URL or key outside `AppConstants`.
