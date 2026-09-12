# SPEC 06 — Confirm or reprocess a shopping receipt and land on the space overview

> **Status:** Approved
> **Depends on:** SPEC 05 (pick-and-process-new-shopping-receipt) — extends `ShoppingReceiptBloc` and the results screen it introduced; backend Shopping Receipt API (`POST /api/v1/spaces/{spaceId}/shopping-receipt/confirm`, `POST /api/v1/spaces/{spaceId}/shopping-receipt/reprocess`, `GET /api/v1/spaces/{spaceId}/overview`, documented in `api_contract.md`)
> **Date:** 2026-09-12
> **Objective:** Wire the results screen's "OK" and "Reprocess selected products" actions to the confirm/reprocess endpoints — reprocess loops back through a new read-only review screen before the user can confirm — and land a successful confirm on a new space overview screen showing every product currently in the space.

---

## Scope

**In:**

- **Results screen — "OK" button:** enabled. Dispatches a confirm action that builds the confirm request from the already-displayed extraction (`receiptImageId`, `shoppingDate` = `purchaseShoppingDate`, `storeName`, `allProducts` mapped from `productExtractions`) and calls `POST /api/v1/spaces/{spaceId}/shopping-receipt/confirm`. On success, navigates straight to the new space overview screen (confirm's own response body isn't rendered — the overview screen re-fetches live).
- **Results screen — "Reprocess selected products" button:** enabled only when at least one product is checked (disabled otherwise — the endpoint requires a non-empty `flaggedProducts`). Dispatches a reprocess action that calls `POST /api/v1/spaces/{spaceId}/shopping-receipt/reprocess` with `flaggedProducts` (the checked subset) and `allProducts` (the full list), plus `language` (device locale, same convention as the original process call). This call both re-extracts **and persists** — see Data model.
- **New Screen 6 — Reprocessed results** (`/process-receipt/reprocessed-results`): read-only list of every product from the reprocess response (no flagged-group styling, no checkboxes, no reprocess option). Single "OK" button that navigates to the space overview screen — this screen makes no API call itself, since reprocess already persisted the data.
- **New Screen 7 — Space overview** (`/space-overview/:spaceId`), new feature module `lib/features/space_overview/`: on entry, fetches `GET /api/v1/spaces/{spaceId}/overview` and displays the space's name/emoji, storage spots, and full product list (already sorted by expiration ascending by the backend) — the "landing point" for this whole flow, reachable independently by `spaceId` so a future spec can also link here.
- **Null `suggestedStorageSpotId` fallback:** when building `allProducts`/`flaggedProducts` for confirm/reprocess, any product whose `suggestedStorageSpotId` is null is defaulted to the first entry in `result.suggestedStorageSpots`.
- **Shared consecutive-failure counter** on `ShoppingReceiptBloc`: the first confirm/reprocess failure (of either kind) shows an inline error (SnackBar) on the Results screen and lets the user retry; a second consecutive failure (no success in between) instead pushes the existing `ReceiptErrorPage` (generalized to also read confirm/reprocess failure messages), whose "OK" goes to `/home`. Counter resets on any confirm/reprocess success or on `ShoppingReceiptFlowReset`.

**Out of scope (for future specs):**

- Editing any product field before confirm/reprocess (name, date, price, storage spot, etc.) — already deferred in SPEC 05, still deferred here.
- The "tap into a space" entry point into the overview screen from outside the receipt-processing flow (e.g. tapping a space card on Home) — this spec only builds the screen and reaches it from this flow's own success paths.
- Any UI distinction between "products that were already in the space" and "products just added by this receipt" on the overview screen — it shows one flat, current list.
- Editing or deleting products/storage spots from the overview screen — view-only.
- Pagination/filtering/custom sorting on the overview screen — the backend's expiration-ascending order is used as-is.

---

## Data model

Extends `lib/features/shopping_receipt/` and introduces a new top-level feature module `lib/features/space_overview/`.

### `shopping_receipt` — new domain entities

```dart
// entities/persisted_product.dart — shape returned by confirm/reprocess (and later reused by the overview response)
class PersistedProduct extends Equatable {
  final String id;                 // real persisted Product id
  final String productName;
  final DateTime expirationDate;
  final String? storageSpotId;     // nullable — backend can leave it unresolved if no matching-type fallback exists
  final String productType;
  final double? priceAmount;
  final String? currency;
}

// entities/persisted_shopping_receipt.dart — confirm/reprocess response shape
class PersistedShoppingReceipt extends Equatable {
  final String id;
  final DateTime shoppingDate;
  final String storeName;
  final List<PersistedProduct> products;
  final List<StorageSpot> storageSpots; // reused from spaces/domain/entities
}
```

### `shopping_receipt` — repository/usecase additions

```dart
abstract class ShoppingReceiptRepository {
  // existing processNewReceipt(...) unchanged

  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>> confirmReceipt({
    required String spaceId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots, // for null-suggestedStorageSpotId fallback
  });

  Future<Either<ShoppingReceiptFailure, PersistedShoppingReceipt>> reprocessReceipt({
    required String spaceId,
    required String receiptImageId,
    required DateTime shoppingDate,
    required String storeName,
    required String language,
    required List<ProductExtraction> flaggedProducts,
    required List<ProductExtraction> allProducts,
    required List<StorageSpot> spaceStorageSpots,
  });
}
// ConfirmShoppingReceiptUseCase / ReprocessShoppingReceiptUseCase — thin pass-throughs, same pattern as ProcessNewShoppingReceiptUseCase
```

`spaceStorageSpots` is `result.suggestedStorageSpots` from the already-loaded extraction — the request-building code (in the repository impl) fills any product's null `suggestedStorageSpotId` with `spaceStorageSpots.first.id` before serializing.

### `shopping_receipt` — data layer additions

```dart
// models/persisted_product_response_model.dart — fromJson()/toEntity(), mirrors PersistedProduct
// models/persisted_shopping_receipt_response_model.dart — fromJson()/toEntity(); storageSpots via existing StorageSpotResponseModel

// datasources/shopping_receipt_remote_datasource.dart (extended)
Future<PersistedShoppingReceiptResponseModel> confirmReceipt({...});   // POST .../shopping-receipt/confirm, JSON body
Future<PersistedShoppingReceiptResponseModel> reprocessReceipt({...}); // POST .../shopping-receipt/reprocess, JSON body

// repositories/shopping_receipt_repository_impl.dart
// confirmReceipt()/reprocessReceipt(): same _mapDioException as processNewReceipt (400/401/403/409/422/429/500/network) —
// no new ShoppingReceiptFailure subtypes needed, confirm/reprocess document the same condition set.
```

### `shopping_receipt` — bloc changes (extends SPEC 05's bloc)

```dart
sealed class ShoppingReceiptStatus {}
Initial / Processing / ProcessSuccess / ProcessFailure(message)   // ProcessSuccess no longer carries the result — see below
Confirming / ConfirmSuccess / ConfirmFailure(message)             // new
Reprocessing / ReprocessSuccess / ReprocessFailure(message)       // new

class ShoppingReceiptState extends Equatable {
  final String? spaceId;
  final String? imagePath;
  final ShoppingReceiptStatus status;
  final ReceiptExtractionResult? extraction;          // NEW — set on ProcessSuccess, persists through Confirming/Reprocessing/*Failure so Results keeps rendering
  final PersistedShoppingReceipt? reprocessedReceipt; // NEW — set on ReprocessSuccess, read by the new Reprocessed-results screen
  final Set<int> selectedForReprocess;
  final int consecutiveFailureCount;                  // NEW — shared confirm/reprocess failure counter
}

sealed class ShoppingReceiptEvent {}
// existing: ShoppingReceiptFlowReset, SpaceForReceiptSelected, ReceiptImagePicked, ReceiptProcessingSubmitted, ReprocessSelectionToggled
ReceiptConfirmSubmitted {}    // new — Results screen's "OK"
ReceiptReprocessSubmitted {}  // new — Results screen's "Reprocess selected products"
```

**Breaking change from SPEC 05:** `ShoppingReceiptProcessSuccess` moves its `result` payload out to `state.extraction`. Without this, `Confirming`/`Reprocessing`/`ConfirmFailure`/`ReprocessFailure` would each need to duplicate the same payload just to let the Results screen keep rendering the list while a confirm/reprocess call is in flight or has failed once. `ReceiptResultsPage` and its tests switch from reading `status.result` to `state.extraction`.

Navigation stays page-level via `BlocListener`, same convention as SPEC 05:

- `ConfirmSuccess` → `context.go('/space-overview/${state.spaceId}')`.
- `ReprocessSuccess` → `context.push('/process-receipt/reprocessed-results')` (transition-guarded `listenWhen`, same fix pattern as SPEC 05's navigation-loop bug).
- `consecutiveFailureCount` transitions to exactly `1` → inline `SnackBar` with the failure message, stay on Results.
- `consecutiveFailureCount` reaches `2` → `context.push('/process-receipt/error')` (existing `ReceiptErrorPage`, generalized to also read `ConfirmFailure`/`ReprocessFailure` messages, not just `ProcessFailure`).

### New feature module `lib/features/space_overview/`

```dart
// domain/entities/space_overview.dart
class SpaceOverview extends Equatable {
  final String id;
  final String name;
  final String emoji;
  final List<StorageSpot> storageSpots;           // reused from spaces/domain/entities
  final List<PersistedProduct> productResults;    // reused from shopping_receipt/domain/entities
}

// domain/repositories/space_overview_repository.dart
abstract class SpaceOverviewRepository {
  Future<Either<SpaceOverviewFailure, SpaceOverview>> getSpaceOverview({required String spaceId});
}
// domain/usecases/get_space_overview_usecase.dart — thin pass-through

// data/models/space_overview_response_model.dart — fromJson()/toEntity(); reuses StorageSpotResponseModel and PersistedProductResponseModel
// data/datasources/space_overview_remote_datasource.dart — GET /api/v1/spaces/$spaceId/overview
// data/repositories/space_overview_repository_impl.dart — _mapDioException covering 400/401/403/409/network only (no 422/429/500 documented for this endpoint)

// core/errors/failures.dart (appended)
sealed class SpaceOverviewFailure { final String message; }
SpaceOverviewValidationFailure(400) / SpaceOverviewUnauthorizedFailure(401) /
SpaceOverviewForbiddenFailure(403) / SpaceOverviewConflictFailure(409) / SpaceOverviewNetworkFailure

// presentation/bloc/space_overview_bloc.dart
sealed class SpaceOverviewStatus {}
Initial / Loading / Success(SpaceOverview) / Failure(message)
sealed class SpaceOverviewEvent {}
SpaceOverviewRequested { final String spaceId; }
class SpaceOverviewState { final SpaceOverviewStatus status; }
```

**Decision to flag:** `SpaceOverviewBloc` is registered in `service_locator.dart` as a **factory** (`getIt.registerFactory`), not an app-root singleton like `SpacesBloc`/`ShoppingReceiptBloc`. The overview screen is a single fetch-and-display per visit with no flow state to preserve across screens, so a fresh instance per navigation (created and provided right at the route, scoped to `/space-overview/:spaceId`) is simpler than a singleton someone has to remember to reset. Route: `GoRoute(path: '/space-overview/:spaceId', ...)`, reading `spaceId` from the path so a future "tap into a space" spec can link here directly.

### New route (`shopping_receipt`)

- `/process-receipt/reprocessed-results` → `ReceiptReprocessedPage`, reads `state.reprocessedReceipt` off `ShoppingReceiptBloc`; single "OK" → `context.go('/space-overview/${state.spaceId}')` (no bloc event — reprocess already persisted).

---

## Implementation plan

1. Add `PersistedProduct`/`PersistedShoppingReceipt` entities, extend `ShoppingReceiptRepository` with `confirmReceipt(...)`, add `PersistedProductResponseModel`/`PersistedShoppingReceiptResponseModel`, `ShoppingReceiptRemoteDataSource.confirmReceipt()` (JSON POST to `.../shopping-receipt/confirm`), `ShoppingReceiptRepositoryImpl.confirmReceipt()` (with the null-`suggestedStorageSpotId` fallback and the existing `_mapDioException`), and `ConfirmShoppingReceiptUseCase`. Manual test: repository test — success mapping, all eight failure statuses, and the fallback behavior for a product with a null suggested spot.
2. Extend `ShoppingReceiptRepository`/`ShoppingReceiptRepositoryImpl`/the datasource with `reprocessReceipt(...)` (JSON POST to `.../shopping-receipt/reprocess`, including `language` and `flaggedProducts`), and `ReprocessShoppingReceiptUseCase`. Manual test: repository test mirroring step 1, plus asserting only the checked subset is serialized as `flaggedProducts` while `allProducts` carries everything.
3. Extend `ShoppingReceiptBloc`/`Event`/`State`: move the `ProcessSuccess` payload out into `state.extraction`; add `Confirming`/`ConfirmSuccess`/`ConfirmFailure`/`Reprocessing`/`ReprocessSuccess`/`ReprocessFailure` statuses, `state.reprocessedReceipt`, `state.consecutiveFailureCount`; add `ReceiptConfirmSubmitted`/`ReceiptReprocessSubmitted` events and their handlers (calling the new usecases, incrementing/resetting the failure counter). Manual test: bloc test covering confirm/reprocess success and failure, the counter reaching 1 then resetting on success, the counter reaching 2 on two consecutive failures, and `ShoppingReceiptFlowReset` clearing all of the above.
4. Update `ReceiptResultsPage`: read `state.extraction` instead of `status.result`; wire "OK" to dispatch `ReceiptConfirmSubmitted`; enable "Reprocess selected products" only when `selectedForReprocess` is non-empty and wire it to dispatch `ReceiptReprocessSubmitted`; disable both buttons and show an inline progress indicator while `status` is `Confirming`/`Reprocessing`. Manual test: update the existing widget tests for the new enabled/disabled/dispatch behavior.
5. Add the `BlocListener` to `ReceiptResultsPage` handling: `ConfirmSuccess` → `context.go('/space-overview/$spaceId')`; `consecutiveFailureCount` reaching exactly 1 → inline `SnackBar`, stay on screen; reaching 2 → push `/process-receipt/error`; `ReprocessSuccess` (transition-guarded) → push `/process-receipt/reprocessed-results`. Generalize `ReceiptErrorPage`'s message extraction to also read `ConfirmFailure`/`ReprocessFailure`. Manual test: widget tests for each listener branch, including the re-fire guard on `ReprocessSuccess`.
6. Build Screen 6 — `ReceiptReprocessedPage` (new route `/process-receipt/reprocessed-results`): flat read-only list from `state.reprocessedReceipt!.products` (name, expiration, resolved storage-spot name, type, price/currency), single "OK" → `context.go('/space-overview/$spaceId')`. Manual test: widget test — renders every product, no checkboxes/reprocess UI, OK navigates correctly.
7. Create the `space_overview` domain layer: `SpaceOverview` entity, `SpaceOverviewRepository`, `GetSpaceOverviewUseCase`, and the `SpaceOverviewFailure` hierarchy in `core/errors/failures.dart`. Manual test: `flutter analyze` passes (interfaces only, no implementer yet).
8. Create the `space_overview` data layer: `SpaceOverviewResponseModel` (reusing `StorageSpotResponseModel`/`PersistedProductResponseModel`), `SpaceOverviewRemoteDataSource.getSpaceOverview()`, `SpaceOverviewRepositoryImpl` (`_mapDioException` for 400/401/403/409/network). Manual test: repository test — success mapping plus all four failure statuses.
9. Create `SpaceOverviewBloc`/`Event`/`State`; register the bloc (`registerFactory`) and its usecase/repository/datasource in `service_locator.dart`; add the `/space-overview/:spaceId` route in `app_router.dart`, building the route-scoped `BlocProvider` inline. Manual test: bloc test — `SpaceOverviewRequested` emits `Loading` then `Success`/`Failure`.
10. Build `SpaceOverviewPage`: loading indicator; error state with message + "Retry" button (re-dispatches `SpaceOverviewRequested`); success state showing the space's name/emoji and a flat product list (name, expiration, resolved storage-spot name, type, price/currency) in the order returned. Manual test: widget tests for loading, error+retry, and success rendering.
11. Run `flutter analyze` and `flutter test` for the full suite, updating any SPEC 05 tests left referencing the old `status.result` shape or the previously-disabled Results buttons.

---

## Acceptance criteria

### Confirm

- [ ] Results screen's "OK" button is enabled and, when pressed, calls `POST /api/v1/spaces/{spaceId}/shopping-receipt/confirm` with `receiptImageId`, `shoppingDate`, `storeName`, and `allProducts` built from the current extraction.
- [ ] Any product with a null `suggestedStorageSpotId` is submitted with the first entry of `suggestedStorageSpots` instead.
- [ ] On success, the app navigates to `/space-overview/{spaceId}`.

### Reprocess

- [ ] "Reprocess selected products" is disabled while no product is checked, and enabled as soon as at least one is.
- [ ] Pressing it calls `POST /api/v1/spaces/{spaceId}/shopping-receipt/reprocess` with `flaggedProducts` (checked subset), `allProducts` (full list), and `language` (device locale).
- [ ] On success, the app navigates to the new reprocessed-results screen — no separate confirm call is made.

### Reprocessed results (Screen 6)

- [ ] Shows every product from the reprocess response, with no checkboxes and no reprocess option.
- [ ] "OK" navigates to `/space-overview/{spaceId}` without making any further API call.

### In-flight and failure handling

- [ ] While a confirm or reprocess request is in flight, both buttons are disabled and an inline progress indicator is shown.
- [ ] The first confirm/reprocess failure shows an inline error (SnackBar) on the Results screen and leaves both buttons usable again.
- [ ] A second consecutive confirm/reprocess failure (no success in between) instead navigates to `ReceiptErrorPage`, whose "OK" goes to `/home`.
- [ ] A confirm or reprocess success resets the consecutive-failure counter to 0.

### Space overview (Screen 7)

- [ ] `/space-overview/{spaceId}` fetches `GET /api/v1/spaces/{spaceId}/overview` on entry.
- [ ] Shows a loading indicator while the request is in flight.
- [ ] On success, shows the space's name, emoji, and every product in `productResults` (name, expiration date, resolved storage-spot name, type, price/currency where present), in the order returned.
- [ ] On failure, shows the failure's message and a "Retry" button that re-fetches.
- [ ] An empty `productResults` renders as an empty list, not an error.

### Data & repository

- [ ] `ShoppingReceiptRepositoryImpl.confirmReceipt()`/`.reprocessReceipt()` map success to `Right(PersistedShoppingReceipt)` and map 400/401/403/409/422/429/500/network to their corresponding `ShoppingReceiptFailure` subtype.
- [ ] `SpaceOverviewRepositoryImpl.getSpaceOverview()` maps success to `Right(SpaceOverview)` and 400/401/403/409/network to their corresponding `SpaceOverviewFailure` subtype.

### Quality gates

- [ ] `flutter analyze` passes with no errors.
- [ ] `flutter test` passes, including new repository/bloc/widget tests and any updated SPEC 05 tests.

---

## Decisions

- **Yes:** Reprocess persists directly (per the backend contract) rather than returning a preview that a second "confirm" call would need to save. The post-reprocess screen is read-only and its "OK" is pure navigation — no redundant mutation call.
- **Yes:** Null `suggestedStorageSpotId` is silently defaulted to the space's first storage spot when building confirm/reprocess requests, rather than blocking the action. This spec has no editing UI to let the user fix it manually, and the backend already applies its own silent fallback for invalid (as opposed to missing) storage-spot ids — client-side defaulting for the missing case is consistent with that.
- **Yes:** `ShoppingReceiptProcessSuccess`'s payload moves out to `state.extraction`, a field that persists across the whole confirm/reprocess lifecycle. Avoids duplicating the same `ReceiptExtractionResult` payload across `Confirming`/`Reprocessing`/`ConfirmFailure`/`ReprocessFailure`, and keeps `ReceiptResultsPage` rendering the list continuously through a failed attempt instead of going blank.
- **Yes:** A single shared consecutive-failure counter across confirm and reprocess, not two independent ones. The concern (don't let the user keep hammering a broken flow, burning AI calls on reprocess) doesn't care which of the two actions is failing.
- **Yes:** Second consecutive failure bounces to the existing `ReceiptErrorPage` rather than a dedicated screen. Reuses SPEC 05's "flow is stuck, only way out is home" pattern instead of building a near-duplicate.
- **Yes:** `SpaceOverviewBloc` is registered as a `registerFactory`, not an app-root singleton like `SpacesBloc`/`ShoppingReceiptBloc`. It has no cross-screen flow state to preserve — a fresh instance per visit, created at the route, is simpler than a singleton that needs manual resetting.
- **Yes:** The overview route takes `spaceId` as a path parameter (`/space-overview/:spaceId`) rather than reading it off `ShoppingReceiptBloc`. Keeps the screen independently reachable for a future "tap into a space" spec, per its own stated purpose in `api_contract.md`.
- **Yes:** `PersistedProduct`/`PersistedShoppingReceipt` live in `shopping_receipt/domain/entities` and are imported by `space_overview`, rather than duplicated. Both confirm/reprocess and the overview endpoint return the exact same product shape.
- **No:** New `ShoppingReceiptFailure` subtypes for confirm/reprocess. Considered, but the documented error conditions are identical to `processNewReceipt`'s — the existing hierarchy already covers them.
- **No:** Grouping the overview screen's products by storage spot. Considered for readability, but out of scope — a flat, expiration-sorted list matches what the backend already returns and avoids inventing UI not requested.

---

## Risks

| Risk | Mitigation |
| --- | --- |
| AI-extracted `productName`/`productType`/`currency` could exceed `ProductRequest`'s max-length constraints (30/30/20 chars), producing a 400 on confirm/reprocess with no way for the user to fix it (editing is out of scope). | No special handling — it's treated as a normal `ShoppingReceiptValidationFailure`; the existing inline-error-then-bounce-to-`ReceiptErrorPage` path is the escape hatch if it recurs. |
| A rapid double-tap on "OK"/"Reprocess selected products" could fire two requests before the bloc's `Confirming`/`Reprocessing` status disables the buttons. | Guard inside the event handlers: ignore `ReceiptConfirmSubmitted`/`ReceiptReprocessSubmitted` if `state.status` is already `Confirming`/`Reprocessing`. |
