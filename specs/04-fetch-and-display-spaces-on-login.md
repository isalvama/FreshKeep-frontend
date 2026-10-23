# SPEC 04 — Fetch and display user's spaces on login

> **Status:** Approved
> **Depends on:** SPEC 01 (login-registration-jwt) — session/JWT; SPEC 03 (create-space-storage-spots) — extends `SpacesBloc`/`HomePage` and `SpaceResponseModel` built there; backend "Get My Spaces" endpoint (`GET /api/v1/spaces`, documented in `api_contract.md`, not yet implemented)
> **Date:** 2026-08-25
> **Objective:** Automatically fetch every space the authenticated user participates in via `GET /api/v1/spaces` right after reaching an authenticated session — whether from a fresh login or a cold app start with a still-valid token — and render it on HomePage alongside the existing in-session, locally-created spaces.

---

## Scope

**In:**

- **Data layer:** `SpaceRemoteDataSource.getSpaces()` — `GET /api/v1/spaces`, parses the JSON array response into `List<SpaceResponseModel>` (an empty array is a valid, non-error response).
- **Repository:** `SpaceRepository.getUserSpaces()` / `SpaceRepositoryImpl.getUserSpaces()` returning `Future<Either<SpaceFailure, List<Space>>>`, reusing the existing `_mapDioException` status-code mapping (401 → `SpaceUnauthorizedFailure`, 403 → `SpaceForbiddenFailure`, unlisted/500 → `SpaceServerFailure`, no response → `SpaceNetworkFailure`).
- **Use case:** `GetUserSpacesUseCase`, depending only on `SpaceRepository`.
- **Emoji cleanup:** simplify `SpaceResponseModel.toEntity()` to read `emoji` directly from the response JSON (drop the `{required emoji}` parameter), since the backend now returns it on both `POST` and `GET`. Update `SpaceRepositoryImpl.createSpace()` to stop threading the submitted emoji through manually.
- **State:** extend `SpacesBloc`/`SpacesState`/`SpacesEvent` — add a `SpacesRequested` event, and a `status` field (`initial` / `loading` / `loaded` / `loadFailure(message)`) on `SpacesState` alongside the existing `spaces: List<Space>` field. The existing `SpaceCreated` handler keeps appending to `spaces` unconditionally, regardless of `status`.
- **Auto-fetch trigger:** a `BlocListener<AuthBloc, AuthState>` placed at the app root (`app.dart`, subscribed from app startup — before any transition into `Authenticated` can occur), dispatching `SpacesRequested` to `SpacesBloc` on every transition into `Authenticated`. Covers both a fresh interactive login (`LoggedIn`) and a cold app start resolving directly to `Authenticated` via a still-valid stored token (`AppStarted`).
- **HomePage:** replace the current single "No spaces yet." branch with four states — loading (spinner), error (message + a "Retry" button that re-dispatches `SpacesRequested`), loaded-and-empty ("No spaces yet."), loaded-with-items (existing list, unchanged).
- **Decoupling:** reaching an authenticated session (login success, or cold start with a valid token) is never blocked by a `GET /api/v1/spaces` failure — the user still lands on HomePage; only the list area shows the error state.
- **DI:** register `GetUserSpacesUseCase` in `lib/core/di/service_locator.dart`.
- **Tests:** repository test for `getUserSpaces()` covering 200-with-items, 200-empty-array, 401, 403, 500, and network-error mapping; widget tests for HomePage's loading / error+retry / empty / populated states.

**Out of scope (for future specs):**

- Pull-to-refresh gesture on HomePage — only the explicit error-state "Retry" button is in scope.
- Pagination or filtering of the spaces list.
- Real-time updates when another user adds you as a participant mid-session — the list only refreshes on next login/cold-start or a manual Retry after a failure.
- Tapping into a space to view its detail/Storage Spots.
- The "create a shopping receipt" flow itself and its space picker — this spec only makes a real spaces list available on `SpacesBloc` for that future flow to consume.
- Any change to `CreateSpaceBloc`/the New Space form beyond the shared `SpaceResponseModel.toEntity()` simplification.

---

## Data model

This spec extends the `spaces` feature module built in SPEC 03 — no new feature module, and no changes to `SpaceFailure` (the existing hierarchy is reused as-is).

### Domain layer (`lib/features/spaces/domain/`)

```dart
// repositories/space_repository.dart — add to the existing interface
abstract class SpaceRepository {
  Future<Either<SpaceFailure, Space>> createSpace({...}); // unchanged signature
  Future<Either<SpaceFailure, List<Space>>> getUserSpaces();
}

// usecases/get_user_spaces_usecase.dart (new)
class GetUserSpacesUseCase {
  final SpaceRepository repository;
  const GetUserSpacesUseCase(this.repository);
  Future<Either<SpaceFailure, List<Space>>> call() => repository.getUserSpaces();
}
```

### Data layer (`lib/features/spaces/data/`)

```dart
// models/space_response_model.dart — emoji becomes a real field, read from JSON
class SpaceResponseModel {
  final String id;
  final String spaceName;
  final String emoji; // now present on both POST and GET responses
  final List<StorageSpotResponseModel> storageSpots;
  final String creatorId;
  final List<String> participantIds;

  factory SpaceResponseModel.fromJson(Map<String, dynamic> json); // parses 'emoji' directly
  Space toEntity(); // no longer takes an emoji parameter — uses this.emoji
}

// datasources/space_remote_datasource.dart — add to the existing class
Future<List<SpaceResponseModel>> getSpaces(); // GET /api/v1/spaces, parses a JSON array ([] when empty)

// repositories/space_repository_impl.dart — add to the existing class
// getUserSpaces(): calls remoteDataSource.getSpaces(), maps each SpaceResponseModel.toEntity(),
// reuses the existing _mapDioException for failures. createSpace() drops its emoji-threading —
// calls response.toEntity() directly.
```

### Presentation layer (`lib/features/spaces/presentation/bloc/spaces_bloc.dart`)

```dart
enum SpacesStatus { initial, loading, loaded, loadFailure }

class SpacesState extends Equatable {
  final List<Space> spaces;       // unchanged role: appended to by SpaceCreated regardless of status
  final SpacesStatus status;
  final String? errorMessage;     // set when status == loadFailure, cleared otherwise

  factory SpacesState.initial() => const SpacesState(spaces: [], status: SpacesStatus.initial, errorMessage: null);
}

sealed class SpacesEvent {}
final class SpaceCreated extends SpacesEvent { final Space space; }       // unchanged from SPEC 03
final class SpacesRequested extends SpacesEvent {}                        // new

// SpacesBloc now depends on GetUserSpacesUseCase (constructor changes from SPEC 03's no-arg SpacesBloc()):
// - SpaceCreated:    appends to `spaces`, `status`/`errorMessage` untouched.
// - SpacesRequested: emits status=loading, calls the use case, then emits
//                     status=loaded + spaces=result on success, or status=loadFailure +
//                     errorMessage=failure.message on failure (spaces left untouched on failure).
```

### Wiring (not new types, but a structural addition)

A `BlocListener<AuthBloc, AuthState>` in `lib/app.dart`, wrapping the existing `MaterialApp.router`, subscribed from app startup. On `previous is! Authenticated && current is Authenticated`, dispatches `SpacesRequested` to the already-provided `SpacesBloc`.

---

## Implementation plan

1. Add `getUserSpaces()` to the `SpaceRepository` interface (`lib/features/spaces/domain/repositories/space_repository.dart`).
2. Create `lib/features/spaces/domain/usecases/get_user_spaces_usecase.dart`, depending only on `SpaceRepository`.
3. Simplify emoji handling in one step (to avoid a broken intermediate state): update `SpaceResponseModel` — add the `emoji` field, parse it in `fromJson`, change `toEntity()` to take no parameters — and update `SpaceRepositoryImpl.createSpace()`'s call site to `response.toEntity()`. Manual test: `flutter analyze` passes; update the existing create-space repository test's canned JSON response to include `"emoji"` and confirm it still passes.
4. Add `SpaceRemoteDataSource.getSpaces()` — `GET /api/v1/spaces`, parsing the JSON array response (including the empty-array case).
5. Implement `SpaceRepositoryImpl.getUserSpaces()`, reusing `_mapDioException`. Manual test: extend `test/features/spaces/data/repositories/space_repository_impl_test.dart` with cases for `getUserSpaces()` — 200-with-items, 200-empty-array, 401, 403, 500, network-error.
6. Extend `SpacesBloc`/`SpacesState`/`SpacesEvent`: add the `SpacesStatus` enum, `errorMessage` field, `SpacesRequested` event + handler; change `SpacesBloc`'s constructor to require a `GetUserSpacesUseCase`.
7. Update `lib/core/di/service_locator.dart`: register `GetUserSpacesUseCase`, and update the `SpacesBloc` registration to inject it. Manual test: `flutter analyze` passes (this step also fixes the compile error step 6 introduces at the registration call site).
8. Wire the auto-fetch trigger in `lib/app.dart`: wrap the existing `MaterialApp.router` in a `BlocListener<AuthBloc, AuthState>` that dispatches `SpacesRequested` to `SpacesBloc` whenever the state transitions into `Authenticated`. Manual test: `flutter run`, log in, confirm `SpacesRequested` fires exactly once; relaunch with a valid stored session and confirm it fires again on cold start without an interactive login.
9. Update `HomePage`: replace the single empty-state branch with four `BlocBuilder<SpacesBloc, SpacesState>` branches keyed off `state.status` — loading spinner, error view + "Retry" button (dispatches `SpacesRequested`), loaded-and-empty text, loaded-with-items list (unchanged rendering).
10. Add widget tests for HomePage's four states to `test/features/auth/presentation/pages/home_page_test.dart`, using a fake `SpaceRepository` wired into a real `SpacesBloc`/`GetUserSpacesUseCase`.
11. Manual end-to-end test against a running backend implementing `GET /api/v1/spaces`: log in, confirm the real list appears; stop the backend and tap Retry to confirm the error view; relaunch the app with a valid stored session and confirm the list populates without an interactive login.
12. Run `flutter analyze` and `flutter test` for the full suite.

---

## Acceptance criteria

### Data & repository

- [ ] `SpaceResponseModel.fromJson()` parses `emoji` directly from the response body; `toEntity()` takes no parameters.
- [ ] `SpaceRepositoryImpl.createSpace()` no longer threads a submitted emoji into `toEntity()` — it reads the response's own `emoji`.
- [ ] `SpaceRemoteDataSource.getSpaces()` calls `GET /api/v1/spaces` and correctly parses both a populated array and an empty array (`[]`).
- [ ] `SpaceRepositoryImpl.getUserSpaces()` maps a successful response to `Right(List<Space>)`, and maps 401/403/500/network failures to the corresponding `SpaceFailure` subtype.

### Auto-fetch trigger

- [ ] `SpacesRequested` is dispatched automatically exactly once after a successful interactive login.
- [ ] `SpacesRequested` is dispatched automatically exactly once when the app cold-starts with a still-valid stored session (no interactive login involved).
- [ ] A failed `GET /api/v1/spaces` call does not prevent or delay reaching HomePage — login/cold-start navigation is unaffected by the fetch's outcome.

### HomePage states

- [ ] While the fetch is in flight, HomePage shows a loading indicator in the list area.
- [ ] On fetch success with a non-empty result, HomePage shows the fetched spaces (emoji + name per item).
- [ ] On fetch success with an empty result, HomePage shows "No spaces yet.".
- [ ] On fetch failure, HomePage shows an error message and a "Retry" button in the list area (the rest of HomePage — FAB, email/logout — remains usable).
- [ ] Tapping "Retry" re-dispatches `SpacesRequested` and, on success, replaces the error view with the fetched list.

### Compatibility with space creation (SPEC 03)

- [ ] After spaces have been fetched (status `loaded`), successfully creating a new space appends it to the visible list immediately, without triggering another `GET /api/v1/spaces` call.
- [ ] If a space is created while the fetch status is `loading` or `loadFailure`, the created space is still appended to `spaces` and becomes visible once the list renders.

### Quality gates

- [ ] `flutter analyze` passes with no errors.
- [ ] `flutter test` passes, including the new `getUserSpaces()` repository tests and the new HomePage state widget tests.

---

## Decisions

- **Yes:** This spec was drafted once `api_contract.md` had a real `GET /api/v1/spaces` section (you updated it mid-session) — the data model reflects the actual documented response shape, not an assumption to verify later.
- **Yes:** Include the `SpaceResponseModel.toEntity()` emoji simplification in this same spec, rather than deferring it. The model is already being touched to add the GET path; leaving two inconsistent emoji-handling code paths (one requiring a caller-supplied emoji, one reading it from JSON) side by side would be confusing.
- **Yes:** `SpacesState` stays a single class with `spaces: List<Space>` plus a separate `status`/`errorMessage`, mirroring `CreateSpaceState`'s pattern — not sealed subtypes (`SpacesLoading`/`SpacesLoaded`/etc., mirroring `AuthState`'s pattern).
- **No:** Sealed `SpacesState` subtypes. Rejected because `SpaceCreated`'s local-append behavior (from SPEC 03) must keep working regardless of fetch status, which is awkward if `spaces` doesn't exist as a field on `Loading`/`LoadFailure` variants.
- **Yes:** HomePage shows an inline error view + "Retry" button in the list area on fetch failure, not a SnackBar over a stale list. Consistent with HomePage's existing loading/empty/list conditional; there's no stale list to show on a first-ever failure anyway.
- **Yes:** The auto-fetch trigger is a `BlocListener<AuthBloc, AuthState>` at the app root (`app.dart`), subscribed from app startup — not scoped to `HomePage`. A listener scoped to `HomePage` would miss the `Authenticated` transition entirely, since `AuthBloc` has already resolved to `Authenticated` by the time `GoRouter`'s redirect mounts `HomePage`, and `BlocListener` only reacts to changes occurring after it subscribes.
- **Yes:** Reaching HomePage is never blocked by a `GET /api/v1/spaces` failure — login/cold-start and the spaces fetch are fully decoupled. Matches SPEC 02's precedent of treating register and login as separate, independently-failable steps; a spaces-fetch failure isn't an authentication failure.
- **Yes:** `SpacesRequested` fires on both a fresh `LoggedIn` and a cold start resolving straight to `Authenticated` via a still-valid stored token — not just interactive login. Otherwise a returning user would see an empty HomePage until an explicit logout/login cycle.
- **Yes:** The "create a shopping receipt" flow and its space picker stay entirely out of scope here — this spec only ensures `SpacesBloc` holds a real, backend-sourced list for that future flow to consume, per the Epic's own Backend/Frontend scope split.
- **Yes:** No pull-to-refresh gesture — only the error-state "Retry" button can re-trigger a fetch. Minimal addition sufficient to recover from a failure; pull-to-refresh is a separate UX enhancement, not requested.

---

## Risks

| Risk | Mitigation |
| --- | --- |
| The app-root `BlocListener<AuthBloc, AuthState>` could theoretically miss the transition into `Authenticated` if it isn't mounted before `AuthBloc` resolves. | `AuthBloc`'s `_onAppStarted`/`_onLoggedIn` handlers run through the bloc's async event queue, so the widget tree (including the listener) is guaranteed built before the first state emission — but verify manually in step 8 rather than assuming. |
| `GET /api/v1/spaces`'s contract only documents 401/403 explicitly (no 500 case listed). | The existing generic `_mapDioException` fallback (unlisted/500 → `SpaceServerFailure`, no response → `SpaceNetworkFailure`) already covers this without any endpoint-specific code. |
| `SpacesBloc`'s constructor now requires a `GetUserSpacesUseCase` (previously no-arg) — any existing test constructing `SpacesBloc()` directly (from SPEC 03's `home_page_test.dart`) will fail to compile. | Step 10 updates those tests to inject a use case (real or fake); `flutter analyze`/`flutter test` in step 12 catches anything missed. |
| The backend's `GET /api/v1/spaces` endpoint doesn't exist yet — step 11's manual end-to-end verification is blocked until the backend sub-issue ships. | Same situation as SPEC 03's Step 18: implementation can proceed and be code-complete/unit-tested without a live backend, but a real manual pass is needed before marking this spec "Implemented". |

---

## What is **not** in this spec

- Pull-to-refresh gesture on HomePage.
- Pagination or filtering of the spaces list.
- Real-time updates when another user adds you as a participant mid-session.
- Tapping into a space to view its detail/Storage Spots.
- The "create a shopping receipt" flow itself and its space picker.
- Any change to `CreateSpaceBloc`/the New Space form beyond the shared `SpaceResponseModel.toEntity()` simplification.

Each one of those, if it lands, goes in its own spec.
