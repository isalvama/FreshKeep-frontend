# SPEC 13 — Join a space from an invitation link

> **Status:** Approved
> **Depends on:**
> - SPEC 12 (create-space-invitation-link): the `freshkeep://join?token=<token>` link and `kInvitationLinkBase` (`lib/core/constants/invitation_constants.dart`).
> - SPEC 01 / SPEC 02 (login-registration-jwt, register-no-auto-login): the `AuthBloc` states and the router's auth redirect, which now keeps a pending token.
> - SPEC 04 (fetch-and-display-spaces-on-login): the app-wide `SpacesBloc` and `SpacesRefreshed`.
> - SPEC 08 (open-space-overview-from-home): the `/space-overview/:spaceId` route, pushed on top of Home after joining.
> - The backend Space API, `POST /api/v1/spaces/invitations/{token}/join` (`api_contract.md`, "Space API Contract" §5).
>
> **Date:** 2026-09-30
> **Objective:** When the app is opened from a `freshkeep://join?token=<token>` link on Android or iOS, the user (after logging in if needed) confirms and joins that space, and lands on its overview.

---

## Scope

**In:**

- **Receiving the link (Android and iOS only):**
  - Add the `app_links` package to `pubspec.yaml`.
  - **Android** (`android/app/src/main/AndroidManifest.xml`):
    - An `intent-filter` on `MainActivity` with `VIEW`, `DEFAULT`, `BROWSABLE` and `<data android:scheme="freshkeep" android:host="join"/>`.
    - `<meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>`, so that Flutter doesn't also hand the link to go_router.
  - **iOS** (`ios/Runner/Info.plist`):
    - `CFBundleURLTypes` with the `freshkeep` scheme.
    - `FlutterDeepLinkingEnabled` = `false`, for the same reason.
  - A new `InvitationLinkListener` in `lib/core/deep_links/`:
    - It subscribes to `AppLinks().uriLinkStream`, which also delivers the link that started the app.
    - For each URI, it extracts the token with a pure `parseInvitationToken(Uri)` that sits next to `kInvitationLinkBase`:
      - A URI that isn't `freshkeep://join` is ignored.
      - A missing or empty token becomes `''`, which leads to the "invalid" page.
    - It then calls `router.push('/join?token=<encoded token>')`.
- **Keeping the token when logged out:**
  - A new `PendingInvitationStore` in `lib/core/deep_links/`. It's an in-memory `get_it` singleton that holds at most one token.
  - The router's `redirect` changes:
    - **Storing:** whenever it moves you away from `/join` (to `/splash` or `/login`), it first stores the token.
    - **Using:** when you're `Authenticated` and it would send you to `/home` (from `/splash`, `/login` or `/register`), it sends you to `/join?token=…` instead and clears the store.
    - **Logging out** clears the store.
- **Spaces feature, domain and data** (extends `lib/features/spaces/`):
  - `SpaceRepository.joinInvitation({token})` and `JoinSpaceInvitationUseCase`, both returning `Either<SpaceFailure, String>`, where the `String` is the joined `spaceId`.
  - `SpaceRemoteDataSource.joinInvitation(token)` calls `dio.post('/api/v1/spaces/invitations/$token/join')` with no body, and reads `spaceId` from the 200 response. The token is URL-encoded as a path segment.
  - The errors have their own mapping for joining:
    - 409 → `SpaceConflictFailure("You're already in this space.")`. The text is fixed and the backend `detail` is ignored.
    - 400 → `SpaceValidationFailure`: the backend `detail`, or "This invitation is invalid or has expired."
    - 401, 403, 500 and network errors → the existing `_mapDioException` defaults.
  - `JoinSpaceInvitationUseCase` is registered in `get_it` as a factory.
- **The `/join` route and page:**
  - A `GoRoute('/join')` reads `token` from the query parameters. It provides a `JoinSpaceBloc` from `get_it` and shows `JoinSpacePage`.
  - `JoinSpaceBloc` lives in `lib/features/spaces/presentation/bloc/` and handles `JoinSpaceSubmitted(token)`. Its status is one of `initial`, `inProgress`, `success`, `alreadyParticipant` or `failure`.
  - `JoinSpacePage` lives in `lib/features/spaces/presentation/pages/` and has four states:
    - **Initial:** an `Icons.group_add` icon, "You've been invited to join a space", a **Join** `FilledButton` and a **Cancel** `TextButton`.
      - Cancel pops back to where you were. If there's nothing to pop (a cold start or after login), it goes to `/home`.
    - **Joining:** a spinner instead of the buttons. There's no way to cancel.
    - **Failure:** the message, plus a **Go to Home** button.
    - **Missing or empty token:** it shows "This invitation link is invalid." and Go to Home straight away, and never calls the backend.
- **After joining:**
  - **Success:** dispatch `SpacesRefreshed`, then `context.go('/home')`, then `context.push('/space-overview/$spaceId')` without `extra`. Back returns to Home.
  - **409:** `context.go('/home')` and the SnackBar "You're already in this space."
- **Tests:**
  - Unit tests for the parser, the store, the redirect rules, the repository and the bloc.
  - Widget tests for the page.
  - Manual tests on a real Android device and a real iOS device (or simulator).

**Out of scope (for future specs):**

- **The https redirect page** that makes the link tappable in WhatsApp, and verified links (App Links / Universal Links).
- **Web, macOS, Linux and Windows.** The scheme isn't registered there, and `InvitationLinkListener` isn't started on those platforms.
- **Showing the space's name or other details before joining.** There's no preview endpoint.
- **Keeping the token after the app is killed during login.** The store is in memory only.
- **Leaving a space, participant management,** and letting the creator see who joined.
- **Links other than `freshkeep://join`.** They're ignored, and no general deep-link routing is added.
- **Changing how SPEC 12 creates or shares links.**

---

## Data model

### Parsing the link: `lib/core/constants/invitation_constants.dart` (extends SPEC 12)

```dart
/// The invitation token in [uri], if [uri] is a `kInvitationLinkBase` link.
/// Returns `null` for any other URI, and `''` when the token is missing.
String? parseInvitationToken(Uri uri);
```

- It compares the `scheme` and `host` with `Uri.parse(kInvitationLinkBase)` (`freshkeep` and `join`), ignoring case.
- The token is `uri.queryParameters['token']`, which is already decoded, trimmed.
- Round trip: `parseInvitationToken(Uri.parse(invitationLink(t))) == t`.

### Pending token: `lib/core/deep_links/pending_invitation_store.dart`

```dart
class PendingInvitationStore {
  String? _token;

  void save(String token) => _token = token; // latest link wins
  String? take();                            // returns the token and clears it
  void clear() => _token = null;
}
```

It's a `get_it` lazy singleton. It's in memory only, and nothing is persisted.

### Listening for links: `lib/core/deep_links/invitation_link_listener.dart`

```dart
class InvitationLinkListener {
  InvitationLinkListener({
    required Stream<Uri> links,          // AppLinks().uriLinkStream in the app
    required void Function(String location) push, // router.push in the app
  });

  void start();          // subscribe; for each URI with a non-null token:
                         // push('/join?token=${Uri.encodeQueryComponent(token)}')
  Future<void> dispose();
}
```

- The stream and `push` are passed in, so tests don't need the plugin or a router.
- It's started only on Android and iOS: `!kIsWeb && (Platform.isAndroid || Platform.isIOS)`.

### Router: `lib/routes/app_router.dart`

```dart
GoRouter buildAppRouter(
  AuthBloc authBloc, {
  required PendingInvitationStore pendingInvitations,
});
```

The new rules are added to the existing `redirect`, in this order:

1. If you're about to leave `/join` for `/splash` or `/login` (because the auth state is `AuthInitial` or you're logged out), save `state.uri.queryParameters['token'] ?? ''` first.
2. If you're `Authenticated` and the existing rule would send you to `/home`, check the store with `take()`. If it holds a token, send you to `/join?token=<encoded>` instead.

The new route:

```dart
GoRoute(
  path: '/join',
  builder: (context, state) => BlocProvider(
    create: (_) => getIt<JoinSpaceBloc>(),
    child: JoinSpacePage(token: state.uri.queryParameters['token'] ?? ''),
  ),
)
```

### Domain and data: `lib/features/spaces/`

```dart
// SpaceRepository
Future<Either<SpaceFailure, String>> joinInvitation({required String token}); // → spaceId

// domain/usecases/join_space_invitation_usecase.dart
class JoinSpaceInvitationUseCase {
  final SpaceRepository repository;
  const JoinSpaceInvitationUseCase(this.repository);

  Future<Either<SpaceFailure, String>> call({required String token}) =>
      repository.joinInvitation(token: token);
}

// SpaceRemoteDataSource
Future<String> joinInvitation(String token);
// dio.post('/api/v1/spaces/invitations/${Uri.encodeComponent(token)}/join')
// → response.data['spaceId'] as String
```

`SpaceRepositoryImpl.joinInvitation` maps a `DioException` like this. The last three rows reuse `_mapDioException`.

| Status | Failure | Message |
|---|---|---|
| 409 | `SpaceConflictFailure` | "You're already in this space." (fixed; `detail` is ignored) |
| 400 | `SpaceValidationFailure` | `detail`, or "This invitation is invalid or has expired." |
| 401 / 403 / 500 | (existing) | (existing) |
| No response | `SpaceNetworkFailure` | (existing) |

The use case and the bloc are registered in `get_it` as factories.

### Presentation: `lib/features/spaces/presentation/bloc/join_space_*.dart`

```dart
// join_space_event.dart
final class JoinSpaceSubmitted extends JoinSpaceEvent {
  final String token;
}

// join_space_state.dart
enum JoinSpaceStatus { initial, inProgress, success, alreadyParticipant, failure }

class JoinSpaceState extends Equatable {
  final JoinSpaceStatus status;
  final String? spaceId;      // set on success
  final String? errorMessage; // set on failure and alreadyParticipant
}
```

- A `SpaceConflictFailure` becomes `alreadyParticipant`, and every other failure becomes `failure`.
- `JoinSpaceSubmitted` is ignored while the status is `inProgress`.
- The bloc checks `isClosed` after the await.
- `JoinSpacePage(token)` handles an empty token itself. It shows the "invalid" view and never dispatches.

---

## Implementation plan

1. **Domain and data** (`lib/features/spaces/`, DI)
   - Add `joinInvitation({token})` to `SpaceRepository`, and add `JoinSpaceInvitationUseCase`.
   - Add `SpaceRemoteDataSource.joinInvitation(token)`:
     - It calls `POST /api/v1/spaces/invitations/<encoded token>/join` with no body.
     - It returns `response.data['spaceId']`.
   - `SpaceRepositoryImpl.joinInvitation` handles errors as follows:
     - 409 → `SpaceConflictFailure("You're already in this space.")`.
     - 400 → `SpaceValidationFailure(detail ?? "This invitation is invalid or has expired.")`.
     - Everything else goes through `_mapDioException`.
   - Register `JoinSpaceInvitationUseCase` in `get_it` as a factory.
   - Add a `joinInvitation` stub to the fake `SpaceRepository`s in existing tests.
   - **Tests:**
     - The request: POST, the path with the token encoded, and no body.
     - Success returns the `spaceId`.
     - 409 with and without `detail` gives the fixed message.
     - 400 with and without `detail`.
     - 401, 403, 500 and network errors.
   - **Check:** analyze is clean and all tests pass. Nothing changes in the UI.

2. **Join page, bloc and route** (`lib/features/spaces/presentation/`, `app_router.dart`, DI)
   - Add `JoinSpaceBloc` with its event and state as `part` files:
     - It emits `inProgress`, then `success` with the `spaceId`, `alreadyParticipant`, or `failure`.
     - It ignores requests while `inProgress`, and checks `isClosed` after the await.
   - Register the bloc in `get_it` as a factory.
   - Add `JoinSpacePage(token)` with the initial, joining, failure and invalid-token views.
     - **Join** dispatches `JoinSpaceSubmitted(token)`.
     - **Cancel** calls `context.pop()` when `context.canPop()`, and `context.go('/home')` otherwise.
     - **Go to Home** calls `context.go('/home')`.
   - A `BlocListener` on the page reacts to the result:
     - `success`: dispatch `SpacesRefreshed`, then `context.go('/home')`, then `context.push('/space-overview/$spaceId')`.
     - `alreadyParticipant`: `context.go('/home')`, then `hideCurrentSnackBar()` and a SnackBar with the message.
   - Add the `GoRoute('/join')` that provides the bloc and reads `token`. The auth redirect is unchanged in this step, so `/join` is only reachable when you're logged in.
   - **Tests:**
     - Bloc tests: success, 409 → `alreadyParticipant`, failure, a second request ignored while one is in progress, and two identical failures both reaching a listener.
     - Widget tests with a `GoRouter`:
       - The initial texts and buttons.
       - The spinner while joining, with no buttons.
       - Success lands on the overview with Home underneath, and `SpacesRefreshed` was dispatched.
       - 409 lands on Home with the SnackBar.
       - Failure shows the message, and Go to Home works.
       - An empty token shows the invalid view and never calls the use case.
       - Cancel pops when there's a page below, and goes to `/home` when there isn't.
   - **Check:** analyze is clean and all tests pass.

3. **Pending token through login** (`lib/core/deep_links/pending_invitation_store.dart`, `app_router.dart`, `app.dart`, DI)
   - Add `PendingInvitationStore` and register it in `get_it` as a lazy singleton.
   - `buildAppRouter` takes the store and adds the two redirect rules from the data model:
     - Save the token when leaving `/join` for `/splash` or `/login`.
     - When you're `Authenticated` and would go to `/home`, go to `/join?token=…` instead if a token was taken from the store.
   - In `app.dart`, the existing `AuthBloc` listener also clears the store when you go from `Authenticated` to logged out.
   - **Tests:** router tests with a controllable `AuthBloc`:
     - Logged out, opening `/join?token=abc` lands on `/login`.
     - After becoming `Authenticated`, you land on `/join?token=abc`, and the store is empty.
     - Cold start: from `AuthInitial` to `Authenticated` also lands on `/join?token=abc`.
     - Going through `/register` and back to `/login` keeps the token.
     - With an empty store, the redirects are unchanged: you go to `/home`.
     - Logging out clears the store.
   - **Check:** analyze is clean and all tests pass.

4. **Receiving the link on Android and iOS** (`pubspec.yaml`, platform files, `lib/core/deep_links/invitation_link_listener.dart`, `invitation_constants.dart`, `app.dart`)
   - Add `app_links` to `pubspec.yaml`.
   - Add `parseInvitationToken(Uri)` next to `invitationLink`.
   - Add `InvitationLinkListener`.
   - Turn `App` into a `StatefulWidget`:
     - `initState` builds the router once, and on Android and iOS starts the listener with `AppLinks().uriLinkStream` and `router.push`.
     - `dispose` disposes the listener.
   - **Android:** add the `freshkeep://join` `intent-filter` and `flutter_deeplinking_enabled=false` to `AndroidManifest.xml`.
   - **iOS:** add `CFBundleURLTypes` (`freshkeep`) and `FlutterDeepLinkingEnabled=false` to `Info.plist`.
   - **Tests:**
     - The parser:
       - A valid link returns the token.
       - The round trip with `invitationLink('a b&c')` works.
       - The scheme and host are compared ignoring case.
       - A missing or empty token returns `''`.
       - Another scheme, another host, or an https URL returns `null`.
     - The listener, with a `StreamController<Uri>`:
       - It pushes `/join?token=<encoded>` for each valid link, including two links in a row.
       - It ignores other URIs.
       - It stops after `dispose`.
   - **Check:** analyze is clean and all tests pass. Then do a native rebuild (`pod install` on iOS).
   - **Manual checks** against the real backend, with a link created through SPEC 12:
     - Android: `adb shell am start -a android.intent.action.VIEW -d "freshkeep://join?token=…"`.
     - iOS: `xcrun simctl openurl booted "freshkeep://join?token=…"`.
     - On each platform:
       - Cold start while logged in, then Join, lands on the overview, with the space on Home.
       - With the app running, in the middle of another screen: Cancel returns you to that screen.
       - While logged out: log in, then you land on the join page.
       - Opening the same link again gives the "already in this space" SnackBar on Home.
       - An expired or made-up token shows the failure page.

---

## Acceptance criteria

**Data and domain**
- [ ] `SpaceRemoteDataSource.joinInvitation('abc')` sends `POST /api/v1/spaces/invitations/abc/join` with no body, and a token such as `a b/c` is URL-encoded in the path.
- [ ] A 200 response `{ "spaceId": "space-9" }` gives `Right('space-9')`.
- [ ] Each error status gives the matching failure:

  | Status | Failure | Message |
  |---|---|---|
  | 409 | `SpaceConflictFailure` | "You're already in this space." (also when `detail` is present) |
  | 400 | `SpaceValidationFailure` | `detail`, or "This invitation is invalid or has expired." |
  | 401 / 403 / 500 | (existing) | (existing) |
  | No response | `SpaceNetworkFailure` | (existing) |

- [ ] `get_it` resolves `JoinSpaceInvitationUseCase` and `JoinSpaceBloc`, gives a new `JoinSpaceBloc` each time, and always gives the same `PendingInvitationStore`.

**Link parsing and listener**
- [ ] `parseInvitationToken(Uri.parse(invitationLink('a b&c')))` returns `'a b&c'`.
- [ ] `FRESHKEEP://JOIN?token=abc` returns `'abc'`.
- [ ] `freshkeep://join` and `freshkeep://join?token=` return `''`.
- [ ] `freshkeep://other?token=abc`, `https://join?token=abc` and `mailto:x` return `null`.
- [ ] For each valid link on the stream, the listener pushes `/join?token=<encoded>` once. It pushes nothing for URIs that return `null`, and nothing after `dispose`.

**Bloc**
- [ ] `JoinSpaceSubmitted` emits `inProgress`, then one of these:
  - `success` with the `spaceId`.
  - `alreadyParticipant` for a `SpaceConflictFailure`.
  - `failure` with the message.
- [ ] A second `JoinSpaceSubmitted` sent while one is `inProgress` doesn't call the use case again.
- [ ] Two identical failures in a row both reach a `BlocListener`.

**Join page**
- [ ] With a token, the page shows "You've been invited to join a space", **Join** and **Cancel**, and doesn't call the backend until Join is tapped.
- [ ] While joining, a spinner shows and neither button is visible.
- [ ] **Success:**
  - The overview of the joined space shows.
  - Back leads to Home.
  - `SpacesRefreshed` was dispatched.
- [ ] **409:** Home shows, with the SnackBar "You're already in this space.".
- [ ] **Other failures:** the page shows the message and **Go to Home**, which leads to Home.
- [ ] **Empty token:** the page shows "This invitation link is invalid." and Go to Home, and the use case is never called.
- [ ] **Cancel** returns to the previous page when there is one, and to Home otherwise.

**Login in between**
- [ ] Logged out, opening `/join?token=abc` shows Login. After logging in, you land on `/join?token=abc` and not on Home.
- [ ] The same happens on a cold start, going from `AuthInitial` to `Authenticated`.
- [ ] The same happens after going to Register and back to Login first.
- [ ] After the token has been used, a later login goes to Home.
- [ ] Logging out clears a pending token.
- [ ] With no pending token, every existing redirect behaves as before.

**Platforms**
- [ ] `AndroidManifest.xml` has the `freshkeep`/`join` `intent-filter` and `flutter_deeplinking_enabled=false`.
- [ ] `Info.plist` has `CFBundleURLTypes` with `freshkeep`, and `FlutterDeepLinkingEnabled=false`.
- [ ] On web, macOS, Linux and Windows the listener isn't started, and the app starts as before.

**Checks**
- [ ] `flutter analyze` reports no issues, and `flutter test` passes.
- [ ] **Manual, on Android and iOS, against the real backend:**
  - A link from SPEC 12, opened on a cold start while logged in, followed by Join, lands on the space's overview, and the space appears on Home.
  - With the app running on another screen, the link opens the join page, and Cancel returns to that screen.
  - Opened while logged out, after logging in you land on the join page.
  - Opening the same link again gives the "already in this space" SnackBar on Home.
  - An expired or made-up token shows the failure page.

---

## Decisions taken and discarded

- **Yes:** `app_links` receives the link, whether the app was closed or running. Flutter's own deep linking is turned off on both platforms.
  - **Discarded:** Flutter's built-in deep linking straight into go_router. With a custom scheme, `join` is parsed as the URI's host and not its path, and the result isn't the same on Android and iOS. With both on, the link would also reach go_router twice.
- **Yes:** Only Android and iOS register the scheme.
  - **Discarded:** web and desktop. There's no use case for them, and each has its own registration.
- **Yes:** Ask before joining, with a `/join` page offering Join and Cancel. A link can be forwarded, so one tap shouldn't be enough to put you in someone's space.
  - **Discarded:** joining straight away.
  - **Discarded:** showing the space's name first. There's no preview endpoint, so it would need a backend change.
- **Yes:** A logged-out user keeps the token in an in-memory `PendingInvitationStore`, and the router's `redirect` uses it after login.
  - **Discarded:** dropping the token, which would force the user to find and tap the link again.
  - **Discarded:** a `from=` query parameter on `/login`, which is lost when the user goes through Register (SPEC 02 returns to Login).
  - **Discarded:** persisting the token, which isn't worth it for a link that lasts 24 hours.
- **Yes:** A link that arrives while the app is running is pushed on top, so Cancel returns to where you were.
  - **Discarded:** `go`, which would throw away whatever you were doing, such as a receipt in progress.
- **Yes:** After joining, go to Home and push the overview, so Back leads to Home with the new space listed. `SpacesRefreshed` is dispatched first.
  - **Discarded:** replacing the whole stack with the overview, which leaves nothing to go back to.
- **Yes:** 409 ("already a participant") goes to Home with a fixed SnackBar. The response has no `spaceId`, so we can't open the right space.
  - **Discarded:** showing it as an error page. Nothing actually went wrong.
- **Yes:** Joining maps its own 409 and 400 messages.
  - **Discarded:** the shared `_mapDioException`. Its 409 text ("You're not a participant of this space.") means the opposite here.
- **Yes:** Other failures, such as 400 or network errors, show a result page with Go to Home.
  - **Discarded:** a SnackBar on Home, which is easy to miss after a cold start.
- **Yes:** An empty or missing token is handled on the page, without calling the backend.
- **Yes:** `JoinSpaceBloc` and `JoinSpacePage` go in `lib/features/spaces/` next to SPEC 12's invitation code, because it's the Space API.
  - **Discarded:** a separate `invitations` feature.
- **Yes:** The join data source returns the `spaceId` as a `String`, with no response model. The response is a single field, and no entity comes from it.
- **Yes:** `InvitationLinkListener` takes a `Stream<Uri>` and a `push` callback, so it can be tested without the plugin or a real router.
- **Yes:** `App` becomes a `StatefulWidget`, so the router is built once and the listener has a stable reference to it. Today the router is rebuilt inside `build()`.

---

## Identified risks

| Risk | Mitigation |
|---|---|
| **Another app can register the same `freshkeep` scheme** and receive the link, including the token. | Accepted, as in SPEC 12: an invitation lasts 24 hours. Verified https links (App Links / Universal Links) need a domain and are the long-term fix. |
| **The link still isn't tappable in WhatsApp and most messaging apps.** The recipient has to copy it into a browser or tap it in an app that supports custom schemes. | Out of scope. The https redirect page is the planned fix. The manual checks use `adb` and `simctl`. |
| **The link is delivered twice:** `app_links` emits the initial link, and it can be emitted again when the app comes back from the background. | The confirmation step means a duplicate is at worst a second join page and not a second join. A second Join gets 409 → Home and the SnackBar. The manual checks cover cold and warm starts. |
| **Pushing `/join` while logged out:** go_router applies the redirect to a pushed route, and how that ends up in the stack isn't obvious. | Step 3's router tests cover a pushed `/join` while logged out landing on `/login` and then on `/join`. If `push` misbehaves there, the listener uses `go` when you're logged out. |
| **The token is lost if the app is killed during login.** | Accepted. The store is in memory only (see Decisions). The user taps the link again. |
| **Turning off Flutter's deep linking** also stops any other URI from reaching go_router. | Nothing uses it today. The only external links are this spec's. |
| **Making `App` a `StatefulWidget`** changes when the router is built, and could break existing navigation. | The whole test suite has to pass. The router is built in `initState` from the same `authBloc`. |
| **New native setup:** `app_links` means a native rebuild (`pod install` on iOS), and the manifest and plist edits are only picked up by a full build. | This is part of Step 4's check. A hot restart isn't enough. |
| **Joining makes you a participant immediately, and there's no way to leave** in the app. | The confirmation step reduces accidental joins. Leaving a space is out of scope. |
