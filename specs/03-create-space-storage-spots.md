# SPEC 03 — Space creation with storage spots

> **Status:** Approved
> **Depends on:** SPEC 01 (login-registration-jwt) — authenticated session, route protection, JWT
> **Date:** 2026-08-21
> **Objective:** Let an authenticated user create a Space (name + emoji + one or more typed Storage Spots) from a FAB-driven creation flow on HomePage, calling `POST /api/v1/spaces`, and see it appear in an in-session space list on HomePage immediately after success.

---

## Scope

**In:**

- **FAB on HomePage:** circular FAB with a "+" icon, bottom of the existing `HomePage` (which keeps its current email + Logout content).
- **Creation bottom sheet:** tapping the FAB opens a `Modal Bottom Sheet` with:
  - An "X" close icon, top-left.
  - Full-width, differently-colored, labeled buttons: **"Create a New Space"** (enabled, navigates to the New Space form) and **"Add a New Receipt"** (visually disabled/greyed out, no tap action — no receipt feature exists yet).
- **"New Space" screen** (route `/create-space`), a vertically scrollable (`SingleChildScrollView`, to avoid keyboard overflow) form:
  - Centered title "New Space".
  - "Space Name" label (left-aligned) + square **emoji picker button**, defaulting to 🏠, to its left, and a `TextField` filling the remaining width to its right. Tapping the emoji button opens an `emoji_picker_flutter` bottom sheet; picking one replaces the button's displayed emoji.
  - **Storage Spots** section, header + dynamic list of rows, starting with one default row (`Fridge` / `FRIDGE`). Each row: a `TextField` (name) + a "Type" button opening a bottom sheet listing the 7 `StorageSpotType` values (`FRIDGE`, `FREEZER`, `PANTRY`, `FRUIT_BOWL`, `WINE_CELLAR`, `COUNTERTOP`, `SHELF`); a trash icon per row to delete it (rows can be deleted down to zero — the Create button's validation, not row-deletion, enforces "at least one spot").
  - "Add Another Storage Spot" button appending a new empty row.
  - All `Container`/button widgets share one consistent corner-radius constant.
- **Validation (real-time, as the user types/leaves a field):**
  - `spaceName` and each spot `name`: 1–30 characters, must contain at least one letter (numeric-only/symbol-only rejected).
  - No two Storage Spots share the same `name` **and** `type` — checked client-side as the list changes, mirroring the backend's own business rule.
  - "Create" stays disabled until `spaceName` is valid and at least one spot row is valid (emoji is always populated via its 🏠 default, so it's never itself a blocker).
- **Submit:** "Create" shows a `CircularProgressIndicator` and disables itself while the request is in flight. Calls `POST /api/v1/spaces` (via the existing `DioClient`, which already attaches `Authorization: Bearer <token>`) with `{ spaceName, emoji, storageSpots: [{ name, type }] }`.
- **Discard-changes dialog:** back navigation off the New Space screen while dirty (spaceName/emoji touched-and-changed from their initial/default value, or the spots list differs from the single default Fridge/FRIDGE row) shows "Discard changes? You have unsaved progress." Navigating back while clean (untouched form) exits without a prompt.
- **Status screen** (route `/create-space/status`):
  - Success: confirmation message + "OK" button back to `/home`. The created Space (using the client-held emoji, since the response omits it) is appended to an in-session Spaces list and is visible on HomePage immediately.
  - Error: a message derived from the failure (validation detail, "Network Error", "Something went wrong", etc.) + "OK" button back to `/create-space`, preserving the entered form data so the user can fix and retry.
- **HomePage extended** to render the in-session list of created spaces (emoji + spaceName per item; no tap/detail action) below/above the existing content.
- **Clean Architecture layers** for the new `spaces` feature (domain entities `Space`/`StorageSpot`/`StorageSpotType`, repository interface, `CreateSpaceUseCase`, data models/datasource/repository impl, `SpaceFailure` hierarchy mirroring `AuthFailure`'s style for 400/401/403/500/network), following SPEC 01/02's conventions.
- **`get_it` introduced for the Spaces feature only** (new `lib/core/di/service_locator.dart`), registering the Space datasource/repository/use case and blocs. Existing auth wiring in `app.dart` is left untouched.
- **New dependencies:** `get_it`, `emoji_picker_flutter` added to `pubspec.yaml`.
- Unit tests: `SpaceRepositoryImpl` status-code-to-failure mapping (same style as the existing auth repository tests), plus tests for the client-side name/duplicate validation logic.

**Out of scope (for future specs):**

- Fetching spaces from the backend (`GET /api/v1/spaces` doesn't exist in the contract) — the HomePage list is in-session only and resets on app restart.
- Viewing a Space's detail (tapping into it, seeing/editing its Storage Spots after creation), editing or deleting a Space or Storage Spot.
- The "Add a New Receipt" feature itself — its bottom-sheet button is present but inert.
- Adding participants to a Space beyond the creator.
- Offline creation/sync queueing — a stable connection is required; a failed request just shows the Error status screen.
- Migrating the existing auth feature's manual DI wiring to `get_it`.
- Any search, filter, or sort of the space list.

---

## Data model

This feature introduces a new `spaces` feature module end-to-end (no existing types are changed except adding to `lib/core/errors/failures.dart`).

### Domain layer (`lib/features/spaces/domain/`)

```dart
// entities/storage_spot_type.dart
enum StorageSpotType { fridge, freezer, pantry, fruitBowl, wineCellar, countertop, shelf }
// maps to/from the backend's UPPER_SNAKE_CASE strings, e.g. fruitBowl <-> 'FRUIT_BOWL'

// entities/storage_spot.dart — a committed spot, as returned by the backend
class StorageSpot {
  final String id;             // storageSpotId
  final String name;
  final StorageSpotType type;
}

// entities/storage_spot_input.dart — a spot to be created (no id yet)
class StorageSpotInput {
  final String name;
  final StorageSpotType type;
}

// entities/space.dart — a committed Space
class Space {
  final String id;
  final String spaceName;
  final String emoji;          // held client-side; backend response never echoes it back
  final List<StorageSpot> storageSpots;
  final String creatorId;
  final List<String> participantIds;
}

// repositories/space_repository.dart — interface, implemented in data/
abstract class SpaceRepository {
  Future<Either<SpaceFailure, Space>> createSpace({
    required String spaceName,
    required String emoji,
    required List<StorageSpotInput> storageSpots,
  });
}

// usecases/create_space_usecase.dart
class CreateSpaceUseCase {
  Future<Either<SpaceFailure, Space>> call({
    required String spaceName,
    required String emoji,
    required List<StorageSpotInput> storageSpots,
  });
}
```

### Shared failures (`lib/core/errors/failures.dart`, appended)

```dart
sealed class SpaceFailure {
  final String message;
  const SpaceFailure(this.message);
}
class SpaceValidationFailure extends SpaceFailure { const SpaceValidationFailure(super.message); } // 400 (field or business-rule)
class SpaceUnauthorizedFailure extends SpaceFailure { const SpaceUnauthorizedFailure(super.message); } // 401
class SpaceForbiddenFailure extends SpaceFailure { const SpaceForbiddenFailure(super.message); } // 403
class SpaceServerFailure extends SpaceFailure { const SpaceServerFailure(super.message); } // 500
class SpaceNetworkFailure extends SpaceFailure { const SpaceNetworkFailure(super.message); } // no connectivity / timeout
```

### Data layer (`lib/features/spaces/data/`)

```dart
// models/storage_spot_request_model.dart
class StorageSpotRequestModel {
  final String name;
  final StorageSpotType type;
  Map<String, dynamic> toJson(); // { "name": ..., "type": "FRIDGE" }
}

// models/create_space_request_model.dart
class CreateSpaceRequestModel {
  final String spaceName;
  final String emoji;
  final List<StorageSpotRequestModel> storageSpots;
  Map<String, dynamic> toJson();
}

// models/storage_spot_response_model.dart
class StorageSpotResponseModel {
  final String storageSpotId;
  final String storageSpotName;
  final StorageSpotType storageSpotType;
  factory StorageSpotResponseModel.fromJson(Map<String, dynamic> json);
  StorageSpot toEntity();
}

// models/space_response_model.dart
class SpaceResponseModel {
  final String id;
  final String spaceName;
  final List<StorageSpotResponseModel> storageSpots;
  final String creatorId;
  final List<String> participantIds;
  factory SpaceResponseModel.fromJson(Map<String, dynamic> json);
  Space toEntity({required String emoji}); // emoji supplied by the caller — the response never carries it
}

// datasources/space_remote_datasource.dart
class SpaceRemoteDataSource {
  Future<SpaceResponseModel> createSpace(CreateSpaceRequestModel request); // via dio, throws DioException on non-2xx
}

// repositories/space_repository_impl.dart
// Implements SpaceRepository: builds the request model, calls the datasource, catches DioException,
// maps HTTP status -> SpaceFailure subtype (400 -> SpaceValidationFailure using the ProblemDetail's
// `detail` or first `errors` entry, 401 -> SpaceUnauthorizedFailure, 403 -> SpaceForbiddenFailure,
// 500 -> SpaceServerFailure, no response -> SpaceNetworkFailure), on success maps
// SpaceResponseModel.toEntity(emoji: <submitted emoji>) -> Right(Space).
```

### Presentation layer (`lib/features/spaces/presentation/bloc/`)

```dart
// spaces_bloc.dart — app-wide, in-session list of created spaces (mirrors AuthBloc's role as global state)
class SpacesState extends Equatable {
  final List<Space> spaces; // starts empty; never fetched, only appended to
}
sealed class SpacesEvent {}
class SpaceCreated extends SpacesEvent { final Space space; }

// create_space_bloc.dart — per-form state for the New Space screen
class StorageSpotRow extends Equatable {
  final String key;   // local id for list/widget identity — NOT a backend id
  final String name;
  final StorageSpotType type;
}

sealed class CreateSpaceStatus {}
class CreateSpaceInitial extends CreateSpaceStatus {}
class CreateSpaceSubmitting extends CreateSpaceStatus {}
class CreateSpaceSuccess extends CreateSpaceStatus { final Space space; }
class CreateSpaceError extends CreateSpaceStatus { final String message; }

class CreateSpaceState extends Equatable {
  final String spaceName;
  final String emoji;              // defaults to '🏠'
  final List<StorageSpotRow> spots; // defaults to one row: name 'Fridge', type StorageSpotType.fridge
  final CreateSpaceStatus status;
  final bool isDirty;              // true once spaceName/emoji/spots diverge from their defaults
  // derived getters (not stored): isSpaceNameValid, spotErrors, duplicateSpotKeys, canSubmit
}

sealed class CreateSpaceEvent {}
class SpaceNameChanged extends CreateSpaceEvent { final String value; }
class EmojiChanged extends CreateSpaceEvent { final String value; }
class StorageSpotAdded extends CreateSpaceEvent {}
class StorageSpotRemoved extends CreateSpaceEvent { final String key; }
class StorageSpotNameChanged extends CreateSpaceEvent { final String key; final String value; }
class StorageSpotTypeChanged extends CreateSpaceEvent { final String key; final StorageSpotType value; }
class CreateSpaceSubmitted extends CreateSpaceEvent {}
```

`CreateSpaceBloc` depends only on `CreateSpaceUseCase` (no direct dependency on `SpacesBloc`) — the `NewSpacePage`'s `BlocListener` reacts to `CreateSpaceSuccess`/`CreateSpaceError` by navigating to `/create-space/status` with the result passed via `GoRouter`'s `extra`, and separately dispatches `SpaceCreated` to `SpacesBloc` on success so it lands on HomePage.

---

## Implementation plan

1. Add `get_it` and `emoji_picker_flutter` to `pubspec.yaml`. Run `flutter pub get`. Manual test: `flutter run` still launches unchanged.
2. Append the `SpaceFailure` sealed hierarchy (`SpaceValidationFailure`, `SpaceUnauthorizedFailure`, `SpaceForbiddenFailure`, `SpaceServerFailure`, `SpaceNetworkFailure`) to `lib/core/errors/failures.dart`.
3. Create the domain layer: `features/spaces/domain/entities/storage_spot_type.dart`, `storage_spot.dart`, `storage_spot_input.dart`, `space.dart`, and `features/spaces/domain/repositories/space_repository.dart` (interface only).
4. Create `features/spaces/domain/usecases/create_space_usecase.dart`, depending only on `SpaceRepository`.
5. Create data models in `features/spaces/data/models/`: `StorageSpotRequestModel`, `CreateSpaceRequestModel`, `StorageSpotResponseModel`, `SpaceResponseModel`, including the `StorageSpotType` <-> `"FRIDGE"`-style string mapping. Manual test: `flutter analyze` passes.
6. Create `features/spaces/data/datasources/space_remote_datasource.dart` using the shared `Dio` client: `createSpace()` against `POST /api/v1/spaces`.
7. Implement `features/spaces/data/repositories/space_repository_impl.dart`: builds the request model, calls the datasource, maps `DioException` status codes to `SpaceFailure` subtypes. Manual test: unit test the status-code-to-failure mapping with a mocked `Dio`, same style as `auth_repository_impl_test.dart`.
8. Create `lib/core/di/service_locator.dart`: a `GetIt` instance with `setupServiceLocator({required Dio dio})` registering `SpaceRemoteDataSource`, `SpaceRepository`, `CreateSpaceUseCase`, `SpacesBloc` (lazy singleton), and `CreateSpaceBloc` (lazy singleton — see step 11 for why singleton, not factory).
9. Create `features/spaces/presentation/bloc/spaces_bloc.dart` (`SpacesState`, `SpacesEvent`/`SpaceCreated`).
10. Create `features/spaces/presentation/bloc/create_space_bloc.dart` (+ event/state files): field-change handlers, add/remove/edit spot-row handlers, derived validation (1–30 chars, ≥1 letter, duplicate name+type), a `CreateSpaceSubmitted` handler calling `CreateSpaceUseCase`, and a `CreateSpaceReset` event that restores the initial state (empty name, default 🏠 emoji, single default Fridge/FRIDGE row).
11. Build shared UI pieces: a shared corner-radius constant (`lib/core/constants/ui_constants.dart`), `widgets/storage_spot_type_sheet.dart` (bottom sheet listing the 7 enum values), `widgets/emoji_picker_button.dart` (wraps `emoji_picker_flutter` in a bottom sheet), `widgets/storage_spot_row.dart` (name field + type button + trash icon).
12. Build `widgets/creation_bottom_sheet.dart`: X close icon, "Create a New Space" button (`context.push('/create-space')`), disabled "Add a New Receipt" button.
13. Build `presentation/pages/new_space_page.dart`: title, Space Name row, Storage Spots section + "Add Another Storage Spot", Create button (disabled until valid, `CircularProgressIndicator` while submitting), wrapped in `SingleChildScrollView`. Back navigation is guarded (`PopScope`) by the discard-changes dialog when `isDirty`; confirming discard dispatches `CreateSpaceReset` before popping. A `BlocListener` reacts to `CreateSpaceSuccess`/`CreateSpaceError`: on success, dispatches `SpaceCreated` to `SpacesBloc` and navigates to `/create-space/status` with the `Space` via `extra`, then dispatches `CreateSpaceReset`; on error, navigates to `/create-space/status` with the error message via `extra` **without** resetting, so a retry preserves the entered data.
14. Build `presentation/pages/space_status_page.dart`: reads `GoRouterState.extra` (success `Space` or error message), shows the confirmation/error UI + "OK" button — success goes `context.go('/home')`, error goes `context.go('/create-space')`.
15. Extend `lib/routes/app_router.dart` with `/create-space` and `/create-space/status` routes (both protected the same way `/home` already is, via the existing `redirect` logic).
16. Extend `lib/features/auth/presentation/pages/home_page.dart`: add the FAB (opens `creation_bottom_sheet`) and a `BlocBuilder<SpacesBloc, SpacesState>` rendering the in-session space list (emoji + spaceName per row) above/below the existing email + Logout content.
17. Wire `lib/app.dart`: call `setupServiceLocator(dio: dioClient.dio)` once the `DioClient` is built, and add `BlocProvider.value` entries for `getIt<SpacesBloc>()` and `getIt<CreateSpaceBloc>()` to the existing `MultiBlocProvider`.
18. Manual end-to-end test: `flutter run`, log in, tap the FAB → "Create a New Space" → submit the default form (🏠 + Fridge/FRIDGE) → confirm the Success status screen → OK → new space visible on HomePage. Repeat forcing a failure (e.g. stop the backend) to confirm the Error status screen appears and "OK" returns to `/create-space` with the form data intact.
19. Run `flutter analyze` and `flutter test` for the full suite.

---

## Acceptance criteria

### Navigation & creation hub

- [ ] A circular FAB with a "+" icon is present at the bottom of HomePage.
- [ ] Tapping the FAB opens a Modal Bottom Sheet with an "X" close icon in the top-left corner.
- [ ] The bottom sheet shows a full-width, distinctly colored "Create a New Space" button with a descriptive label, and a full-width "Add a New Receipt" button that is visually disabled and does nothing when tapped.
- [ ] Tapping "Create a New Space" navigates to `/create-space`, a vertically scrollable screen titled "New Space" (centered).

### New Space form

- [ ] The form shows a left-aligned "Space Name" label, a square emoji-picker button defaulting to 🏠, and a `TextField` filling the remaining width.
- [ ] Tapping the emoji button opens an emoji picker bottom sheet; picking an emoji updates the button's displayed emoji.
- [ ] The Storage Spots section starts with exactly one row: name "Fridge", type `FRIDGE`.
- [ ] Each Storage Spot row has a name `TextField` and a "Type" button.
- [ ] Tapping "Type" opens a bottom sheet listing all 7 `StorageSpotType` values (`FRIDGE`, `FREEZER`, `PANTRY`, `FRUIT_BOWL`, `WINE_CELLAR`, `COUNTERTOP`, `SHELF`); selecting one sets the row's type.
- [ ] "Add Another Storage Spot" appends a new empty row.
- [ ] Each row has a trash icon that removes that row; rows can be deleted down to zero.
- [ ] All `Container`/button widgets share the same corner radius.
- [ ] The screen uses `SingleChildScrollView`; filling every field with the keyboard open produces no bottom-overflow error.

### Validation

- [ ] A `spaceName` or spot `name` outside 1–30 characters shows a real-time validation error.
- [ ] A `spaceName` or spot `name` containing no letters (numeric-only or symbol-only) shows a real-time validation error.
- [ ] Adding/editing a Storage Spot to share the same name **and** type as an existing row shows a real-time duplicate error and is prevented from being submitted.
- [ ] The "Create" button is disabled until `spaceName` is valid and at least one Storage Spot row is valid.

### Submission

- [ ] Tapping "Create" while valid shows a `CircularProgressIndicator` on the button and disables it for the duration of the request.
- [ ] The request is `POST /api/v1/spaces` with body `{ spaceName, emoji, storageSpots: [{ name, type }] }` and header `Authorization: Bearer <token>`.
- [ ] On `201 Created`, the app navigates to the Status screen showing a success message and an "OK" button.
- [ ] Tapping "OK" on the success Status screen returns to HomePage, and the newly created space (emoji + spaceName) is visible in HomePage's list immediately, without needing an app restart or manual refresh.
- [ ] On a failed request (validation 400, network error, 401/403/500), the app navigates to the Status screen showing a clear error message and an "OK" button.
- [ ] Tapping "OK" on the error Status screen returns to `/create-space` with the previously entered `spaceName`, emoji, and Storage Spot rows still populated.

### Discard-changes guard

- [ ] Navigating back from `/create-space` while the form is untouched (still the default `spaceName`/emoji/single Fridge row) exits without a prompt.
- [ ] Navigating back from `/create-space` after any field was changed or a row was added/edited/removed shows a "Discard changes? You have unsaved progress." dialog.
- [ ] Confirming discard resets the form to its default state for the next time it's opened.

### Persistence & session

- [ ] The HomePage space list is populated only from spaces created in the current app session — restarting the app returns to an empty list (no `GET /api/v1/spaces` call is made, since the endpoint doesn't exist).
- [ ] Every request to `/api/v1/spaces` includes the stored JWT via the existing `Authorization: Bearer <token>` interceptor.

### Quality gates

- [ ] `flutter analyze` passes with no errors.
- [ ] `flutter test` passes, including new tests for `SpaceRepositoryImpl`'s status-code-to-failure mapping and the client-side name/duplicate validation logic.

---

## Decisions

- **Yes:** HomePage's space list is in-session/in-memory only (a `SpacesBloc` holding `List<Space>`), populated solely by appending on successful creation. No `GET /api/v1/spaces` call is made and nothing persists across restarts.
- **No:** Client-side persistence (Hive/shared_preferences) for the space list. Rejected — adds scope for data that would still diverge from the backend's eventual source of truth once a GET endpoint exists.
- **No:** Deferring the HomePage list to a separate spec. Rejected — AC 4.2 ("visible in list immediately") needs to be verifiable within this spec.
- **Yes:** `get_it` is introduced, but scoped to the new Spaces feature only (`lib/core/di/service_locator.dart`). Matches `CLAUDE.md`'s DI mandate for new work without retrofitting the existing auth wiring.
- **No:** Leaving Spaces on manual constructor wiring like auth, or migrating auth to `get_it` in this same spec. Both rejected as either ignoring the CLAUDE.md mandate or scope creep unrelated to this user story.
- **Yes:** `emoji_picker_flutter` package for the emoji selector. Closest match to "custom emoji selector" with minimal build effort.
- **Yes:** Client-enforced `spaceName` max length is 30 characters, matching both the user story and the backend's `CreateSpaceRequest.spaceName` (now accepting up to 30 chars). Same limit as Storage Spot names — no special-casing needed between the two.
- **Yes:** A dedicated routed Status screen (`/create-space/status`) for both success and error, per AC 4.2's literal wording.
- **Yes:** The "Add a New Receipt" bottom-sheet button is present but disabled (no route, no tap action). Satisfies AC 1.2's "buttons for different resources" without building a feature that doesn't exist yet.
- **No:** A TODO-stub route for Receipt, or omitting the button entirely. Both rejected — one builds dead surface area, the other doesn't satisfy AC 1.2 as written.
- **Yes:** Validation is real-time (as the user types/leaves a field), diverging from SPEC 01/02's on-submit-only convention for Login/Register. Required by the user story's real-time feedback (AC 3.3) and the disabled-until-valid Create button (Addition #4), which needs continuously computed validity anyway.
- **Yes:** The existing `HomePage` (currently just email + Logout) is extended in this spec with the FAB and space list, rather than deferred.
- **Yes:** The discard-changes dialog's "dirty" check compares current values against the form's defaults (empty name, 🏠 emoji, single Fridge/FRIDGE row) rather than treating the screen as dirty the instant it opens. Avoids prompting on an accidental, zero-input back-tap.
- **Yes:** The emoji field defaults to 🏠 rather than starting empty/required-pick. Explicit user request; also removes emoji as a blocker for enabling "Create".
- **Yes:** Routes are flat — `/create-space` and `/create-space/status` — matching the existing `/login`, `/register`, `/home` style and the current branch name, over a nested `/spaces/new` style.
- **Yes:** `CreateSpaceBloc` is registered as a `get_it` lazy singleton (not a per-route factory), with an explicit `CreateSpaceReset` event fired only after a successful creation's status-OK or a confirmed discard. This is the only way to satisfy both "Error OK preserves entered data" and "a fresh FAB tap starts a clean form" without threading draft field values through `extra` as a second channel.
- **Yes:** Storage Spot name+type duplicate prevention is enforced client-side, mirroring the backend's own `InvalidSpaceException` rule, per AC 3.2/3.3's explicit UI requirement — not just left to surface after a round trip.

---

## Risks

| Risk | Mitigation |
| --- | --- |
| `CreateSpaceBloc` is a `get_it` singleton whose reset only fires on two specific paths (success-OK, confirmed discard). If the user leaves `/create-space`/`/create-space/status` some other way (OS back-gesture, app backgrounding mid-flow), stale state could leak into the next FAB-triggered session. | Manually test back-gesture/backgrounding during implementation; if a gap is found, widen the reset trigger to any route change away from the creation flow rather than only the two explicit buttons. |
| Client-side "must contain at least one letter" and duplicate-name+type detection must match the backend's own business rules (`InvalidSpaceNameException`, `InvalidStorageSpotName`, `InvalidSpaceException`) closely enough to avoid false negatives/positives (e.g. accented or non-Latin letters). | Keep this logic in small, directly unit-tested pure functions (per the Acceptance Criteria quality-gate tests) rather than inline widget logic; the backend's own 400 response remains a safety net surfaced via `SpaceValidationFailure`. |
| `emoji_picker_flutter` is a new third-party dependency with unverified behavior/asset size on this project's target platforms (iOS/Android/web/desktop) and its own bottom-sheet styling may not match the shared corner-radius convention. | Verify manually on at least Android and iOS during implementation; treat any web/desktop gap or visual mismatch as a follow-up rather than blocking this spec. |

---

## What is **not** in this spec

- Fetching spaces from the backend (`GET /api/v1/spaces` doesn't exist in the contract) — the HomePage list is in-session only and resets on app restart.
- Viewing a Space's detail, editing or deleting a Space or Storage Spot after creation.
- The "Add a New Receipt" feature itself — its bottom-sheet button is present but inert.
- Adding participants to a Space beyond the creator.
- Offline creation/sync queueing.
- Migrating the existing auth feature's manual DI wiring to `get_it`.
- Any search, filter, or sort of the space list.

Each one of those, if it lands, goes in its own spec.
