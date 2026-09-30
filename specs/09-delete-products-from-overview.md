# SPEC 09 — Delete products from a space's overview

> **Status:** Approved
> **Depends on:** SPEC 06 (confirm-reprocess-and-space-overview) — extends `SpaceOverviewBloc`, its state and `SpaceOverviewPage`; SPEC 08 (open-space-overview-from-home) — the overview's AppBar (title and leading button) gets a selection-mode variant. Uses the backend Product API: `DELETE /api/v1/products/{id}` and `DELETE /api/v1/products` (`api_contract.md`, "Product API Contract" §3–4).
> **Date:** 2026-09-30
> **Objective:** From a space's overview, the user can select one or more products with a long press and delete them after confirming, removing them from the list on success.

---

## Scope

**In:**

- **Products feature — domain and data (new `lib/features/products/`):**
  - `ProductRepository` (interface), `DeleteProductUseCase`, `DeleteProductsUseCase`.
  - `ProductRemoteDataSource` (`dio.delete('/api/v1/products/$id')` and `dio.delete('/api/v1/products', data: {'productsIds': [...]})`) and `ProductRepositoryImpl` mapping `DioException` → `ProductFailure`.
  - New sealed `ProductFailure` in `core/errors/failures.dart`; use cases, data source and repository registered in `get_it`.
- **Selection mode on the overview:**
  - A long press on a product row enters selection mode with that product selected.
  - In selection mode, rows show a checkbox; tapping a row toggles it.
  - The AppBar switches to: leading ✕ (clears the selection), title `"N selected"`, trailing delete `IconButton`.
  - System back / back gesture clears the selection instead of leaving the page (`PopScope`).
  - Deselecting the last product leaves selection mode.
- **Confirmation:** the delete icon opens a dialog `"Delete N product(s)?"` with "Cancel" (dispatches nothing) and "Delete" (dispatches `SelectedProductsDeleteSubmitted`).
- **Deleting:**
  - Exactly 1 selected → `DELETE /api/v1/products/{id}`; 2 or more → `DELETE /api/v1/products` with `productsIds`.
  - While the request runs, the delete icon is replaced by a small spinner, and the ✕, back, row taps and long presses do nothing.
- **Success:** the deleted products are removed from the loaded overview locally (no refetch), selection mode ends, and a SnackBar shows `"1 product deleted"` / `"N products deleted"`. If the list becomes empty, the existing `"No products yet."` shows.
- **Failure:** nothing is removed, the selection stays, and a SnackBar shows the failure message (backend `detail` when present).
- **Bloc:** `SpaceOverviewBloc` gains the selection and deletion state and the events `ProductSelectionToggled`, `ProductSelectionCleared` and `SelectedProductsDeleteSubmitted`.

**Out of scope (for future specs):**

- "Select all" or any bulk-selection shortcut.
- Undo / restore of deleted products (no restore endpoint exists).
- Swipe-to-delete.
- Editing or moving products (`PATCH /api/v1/products/{id}`, `/storage-spot`).
- Deleting spaces or storage spots.
- Refetching the overview or Home's spaces list after a delete.
- Any change to the overview endpoint, its model or `GetSpaceOverviewUseCase`.

---

## Data model

No new entities. The overview's `PersistedProduct.id` is the product id the endpoints take.

### `core/errors/failures.dart` — new failure type

```dart
sealed class ProductFailure {
  final String message;

  const ProductFailure(this.message);
}

class ProductValidationFailure extends ProductFailure {
  const ProductValidationFailure(super.message); // 400 — product doesn't exist, invalid id
}

class ProductUnauthorizedFailure extends ProductFailure {
  const ProductUnauthorizedFailure(super.message); // 401
}

class ProductForbiddenFailure extends ProductFailure {
  const ProductForbiddenFailure(super.message); // 403
}

class ProductConflictFailure extends ProductFailure {
  const ProductConflictFailure(super.message); // 409 — not a participant
}

class ProductNetworkFailure extends ProductFailure {
  const ProductNetworkFailure(super.message); // no connectivity / timeout / other
}
```

`ProductRepositoryImpl` uses the backend `detail` when present, otherwise these defaults:

| Status | Default message |
|---|---|
| 400 | `'Some of these products no longer exist.'` |
| 401 | `'Your session has expired. Please log in again.'` |
| 403 | `'You are not allowed to perform this action.'` |
| 409 | `'You are not a participant of this space.'` |
| other | `e.message ?? 'Network error. Please check your connection.'` |

### `products` feature — domain and data

```dart
// domain/repositories/product_repository.dart
abstract class ProductRepository {
  Future<Either<ProductFailure, Unit>> deleteProduct({required String productId});
  Future<Either<ProductFailure, Unit>> deleteProducts({required List<String> productIds});
}

// domain/usecases/delete_product_usecase.dart   → call({required String productId})
// domain/usecases/delete_products_usecase.dart  → call({required List<String> productIds})

// data/datasources/product_remote_datasource.dart
//   deleteProduct:  dio.delete('/api/v1/products/$productId')
//   deleteProducts: dio.delete('/api/v1/products', data: {'productsIds': productIds})
```

There are no response models, because both endpoints return `204` with no body.

### `space_overview` — bloc state

```dart
// presentation/bloc/space_overview_state.dart
sealed class ProductDeletionStatus { const ProductDeletionStatus(); }
final class ProductDeletionIdle extends ProductDeletionStatus { … }
final class ProductDeletionInProgress extends ProductDeletionStatus { … }
final class ProductDeletionSuccess extends ProductDeletionStatus {
  final int deletedCount; // drives the SnackBar text
}
final class ProductDeletionFailure extends ProductDeletionStatus {
  final String message;
}

class SpaceOverviewState extends Equatable {
  final SpaceOverviewStatus status;
  final Set<String> selectedProductIds;          // empty = not in selection mode
  final ProductDeletionStatus deletionStatus;    // initial: ProductDeletionIdle

  bool get isSelecting => selectedProductIds.isNotEmpty;
  // copyWith + props include the new fields
}
```

### `space_overview` — new bloc events (past tense)

```dart
final class ProductSelectionToggled extends SpaceOverviewEvent {
  final String productId; // adds if absent, removes if present
}
final class ProductSelectionCleared extends SpaceOverviewEvent {}
final class SelectedProductsDeleteSubmitted extends SpaceOverviewEvent {}
```

### `SpaceOverviewBloc` behavior

The bloc gains `deleteProductUseCase` and `deleteProductsUseCase`, injected through `get_it`.

- **`ProductSelectionToggled`** and **`ProductSelectionCleared`** are ignored while `deletionStatus` is `InProgress`.
- **`SelectedProductsDeleteSubmitted`:**
  - It is ignored if the selection is empty or a delete is already in progress.
  - Otherwise it emits `InProgress`. With 1 id it calls `deleteProductUseCase`; with 2 or more it calls `deleteProductsUseCase`.
  - On **Right**, it emits a new `SpaceOverviewLoadSuccess` whose `productResults` no longer contain the deleted ids. The selection becomes empty and the status becomes `ProductDeletionSuccess(count)`.
  - On **Left**, it emits `ProductDeletionFailure(message)` and the selection is unchanged.
- **`SpaceOverviewRequested`** also resets the selection to empty and `deletionStatus` to `Idle`.

The page shows the SnackBars from a `BlocListener`, which fires when `deletionStatus` changes to `Success` or `Failure`. The status classes aren't `Equatable`, the same as `SpaceOverviewStatus`, so two failures in a row each get a SnackBar.

---

## Implementation plan

1. **Products domain and data.**
   - Add `ProductFailure` and its subclasses to `core/errors/failures.dart`.
   - Create `lib/features/products/` with:
     - `ProductRepository`
     - `DeleteProductUseCase`, `DeleteProductsUseCase`
     - `ProductRemoteDataSource`
     - `ProductRepositoryImpl`, with the status → failure mapping and default messages from the data model
   - Register the data source, repository and both use cases in `service_locator.dart`. Nothing uses them yet.

   Manual test: repository tests.
   - Single delete calls `DELETE /api/v1/products/<id>`.
   - Batch delete calls `DELETE /api/v1/products` with body `{'productsIds': [...]}`.
   - `204` → `Right(unit)`.
   - 400, 401, 403 and 409 map to the right failure, using `detail` when present and the default otherwise.
   - A connection error maps to `ProductNetworkFailure`.

2. **Bloc selection and deletion.**
   - Add `ProductDeletionStatus`, `selectedProductIds` and `isSelecting` to `SpaceOverviewState`.
   - Add the events `ProductSelectionToggled`, `ProductSelectionCleared` and `SelectedProductsDeleteSubmitted`, with their handlers.
   - Make `SpaceOverviewRequested` reset the selection and the deletion status.
   - Inject both use cases into `SpaceOverviewBloc`, and update its `get_it` factory and every existing test that constructs it.

   The UI doesn't dispatch the new events yet.

   Manual test: bloc tests.
   - Toggle adds and removes an id, and clear empties the selection.
   - Submitting with 1 id calls only `deleteProductUseCase`; with 2 or more, only `deleteProductsUseCase`, with all the ids.
   - Success removes exactly those products, clears the selection and emits `Success(count)`.
   - Failure keeps the list and the selection and emits `Failure(message)`.
   - Toggle, clear and submit are ignored while `InProgress`.
   - Submitting with an empty selection does nothing.

3. **UI: selection mode.** In `SpaceOverviewPage`, loaded state:
   - A long press on a row dispatches `ProductSelectionToggled` when not selecting.
   - While selecting:
     - Rows show a `Checkbox`, and tapping a row dispatches `ProductSelectionToggled`.
     - The AppBar shows a leading ✕ (`Icons.close`, tooltip `'Cancel selection'`) that dispatches `ProductSelectionCleared`, and the title `"N selected"`.
     - A `PopScope` with `canPop: !state.isSelecting` turns back into `ProductSelectionCleared`.
   - No delete icon yet.

   Manual test: widget tests.
   - A long press enters selection mode with that row checked and "1 selected".
   - Tapping rows toggles them and updates the count, and deselecting the last one leaves selection mode.
   - ✕ clears the selection.
   - Back while selecting clears the selection and stays on the page.
   - Outside selection mode, the SPEC 08 title and leading button are unchanged.

4. **UI: delete, confirmation and feedback.**
   - While selecting, the AppBar gets a trailing delete `IconButton` (`Icons.delete_outline`, tooltip `'Delete selected'`).
   - It opens an `AlertDialog`: title `"Delete N product(s)?"`, with "Cancel", which dispatches nothing, and "Delete", which dispatches `SelectedProductsDeleteSubmitted`.
   - While `InProgress`:
     - The icon is replaced by a small `CircularProgressIndicator`.
     - ✕, back, row taps and long presses do nothing, because the bloc ignores them.
   - A `BlocListener` shows a SnackBar:
     - `"1 product deleted"` or `"N products deleted"` on `Success`
     - the message on `Failure`

   Manual test: widget tests.
   - The icon opens the dialog with the right count.
   - Cancel dispatches nothing.
   - Delete with 1 selected hits the single use case; with 2, the batch one.
   - The spinner shows while the request is in flight.
   - On success, the rows disappear, selection mode ends and the SnackBar shows.
   - Deleting every product shows "No products yet."
   - On failure, the rows and selection stay and the SnackBar shows the message.

5. **Full verification.** Run `flutter analyze` and the full `flutter test` suite. Both must be clean.

After Step 1 the app is unchanged. After Step 3 selection works without deleting. After Step 4 the feature is complete.

---

## Acceptance criteria

**Selection**

- [ ] Long-pressing a product row on a loaded overview enters selection mode with that product selected.
- [ ] In selection mode every row shows a checkbox, and tapping a row toggles its selection.
- [ ] The AppBar in selection mode shows a leading ✕ (tooltip `'Cancel selection'`), the title `"N selected"` with the current count, and a delete icon (tooltip `'Delete selected'`).
- [ ] ✕ clears the selection and leaves selection mode.
- [ ] System back / back gesture in selection mode clears the selection and stays on the overview.
- [ ] Deselecting the last selected product leaves selection mode.
- [ ] Outside selection mode, the overview looks and behaves exactly as after SPEC 08, including the title, leading button and back navigation.

**Confirmation**

- [ ] The delete icon opens a dialog titled `"Delete N product(s)?"` with the selected count.
- [ ] "Cancel" closes the dialog, dispatches nothing and keeps the selection.
- [ ] "Delete" closes the dialog and starts the deletion.

**Deleting**

- [ ] With exactly 1 product selected, the app calls `DELETE /api/v1/products/{id}` and not the batch endpoint.
- [ ] With 2 or more selected, the app calls `DELETE /api/v1/products` once, with every selected id in `productsIds`.
- [ ] While the request is in flight, the delete icon is replaced by a spinner, and ✕, back, row taps and long presses have no effect.
- [ ] On success, exactly the deleted products disappear from the list without refetching the overview, selection mode ends, and a SnackBar shows `"1 product deleted"` or `"N products deleted"`.
- [ ] If the success leaves the space with no products, `"No products yet."` is shown.
- [ ] On failure, no product is removed, the selection is kept, and a SnackBar shows the backend `detail`, or the default message for that status.
- [ ] After a failure, the user can press delete again and retry.

**Architecture**

- [ ] The domain and data code lives in `lib/features/products/`, and `ProductFailure` lives in `core/errors/failures.dart`.
- [ ] Use cases, data source and repository come from `get_it`, and the widgets only dispatch events and listen to state.
- [ ] `SpaceOverviewRequested` resets the selection and the deletion status.
- [ ] The overview endpoint, its model and `GetSpaceOverviewUseCase` are unchanged.

**Quality**

- [ ] `flutter analyze` reports no issues.
- [ ] `flutter test` passes in full, including the new repository, bloc and widget tests.

---

## Decisions taken and discarded

| Decision | Chosen | Discarded | Why |
|---|---|---|---|
| Endpoint | Single `DELETE /products/{id}` for 1 product, batch `DELETE /products` for 2+ | Always batch | Uses each endpoint for what it's designed for; the single call is the natural fit for the most common case. |
| Selecting products | Long press enters selection mode (checkboxes, contextual AppBar) | Always-visible checkboxes; swipe-to-delete + selection | Standard Material pattern; keeps the read-only view clean; one gesture covers one or many products. |
| Confirmation | Always a dialog `"Delete N product(s)?"` | SnackBar with Undo; no confirmation | Deletion can't be undone from the app — there is no restore endpoint. |
| After success | Remove the deleted products locally; no refetch | Reload the whole overview; remove locally + silent reload | The batch endpoint is all-or-nothing and both return `204`, so success means exactly those products are gone. |
| In-progress / failure | Inline spinner in place of the delete icon, selection locked; on failure keep selection + SnackBar | Full-screen spinner | The list stays visible, and after a failure the user can retry without selecting again. |
| Where domain/data lives | New `lib/features/products/` + `ProductFailure` | Inside `space_overview/` | The Product API has its own base path, and update and move will join this feature later. |
| Who owns selection and deletion | `SpaceOverviewBloc` (new state fields and events) | Separate `ProductDeletionBloc` | This bloc owns the list that gets pruned, so no coordination between blocs is needed. |
| Back in selection mode | Clears the selection (`PopScope`); deselecting the last product leaves the mode | Back leaves the page while selecting | Matches platform conventions; avoids leaving the screen by accident mid-selection. |
| "Select all" | Out of scope | Include now | Not needed for the core flow; can be added later without changing this design. |
| SnackBar text | `"1 product deleted"` / `"N products deleted"` | Generic `"Deleted"` | Confirms how many products were affected. |

---

## Identified risks

| Risk | Impact | Mitigation |
|---|---|---|
| A `DELETE` request with a JSON body (batch endpoint) gets stripped by a proxy or a platform HTTP client. | The backend gets no `productsIds`, returns 400 and nothing is deleted. | Dio sends the body on mobile, desktop and web. A repository test asserts the body. Check once against the real backend, including on web. |
| The list is stale because another participant already deleted or moved one of the selected products. | Single delete returns 400. Batch delete is all-or-nothing, so the whole request fails, and retrying keeps failing. | The failure SnackBar shows the backend message. Leaving and reopening the overview refetches it. Automatic refetch on failure is out of scope. |
| A delete response arrives after the overview was reloaded or is no longer `LoadSuccess`. | Products would be pruned from an outdated overview, or the status would be overwritten. | On success, prune only if the status is still `SpaceOverviewLoadSuccess`, and remove by id, not by index. |
| The page is closed while a delete is in flight, for example on logout. | The bloc would emit after it was closed. | Back is blocked while selecting, and the handler only emits while the bloc is still open (`emit.isDone` / `isClosed` guard). |
| `PopScope` intercepts back in a way that conflicts with SPEC 08's leading button, which uses `canPop()`. | The user can't leave the overview, or leaves it by accident. | `canPop` is `false` only while selecting. Outside selection mode the SPEC 08 behavior is unchanged, and widget tests cover both. |
