# SPEC 11 — Move a product to another storage spot

> **Status:** Implemented
> **Depends on:**
> - SPEC 04 (fetch-and-display-spaces-on-login): reads the user's spaces and their storage spots from `SpacesBloc`.
> - SPEC 09 (delete-products-from-overview): reuses selection mode, `lib/features/products/`, `ProductRepository`, `ProductRemoteDataSource` and `ProductFailure`, and adds an action to the selection-mode AppBar.
> - SPEC 10 (edit-product-from-overview): reuses `_sortedByExpiration`, the stable re-sort of the overview's products.
> - The backend Product API, `PATCH /api/v1/products/{id}/storage-spot` (`api_contract.md`, "Product API Contract" §2).
>
> **Date:** 2026-09-30
> **Objective:** From a space's overview, the user can select exactly one product and move it to any storage spot of any space they take part in, with the backend recalculating its expiration date and the overview updated locally on success.

---

## Scope

**In:**

- **Products feature, domain and data** (extends `lib/features/products/`):
  - A `MovedProduct` entity with `productId`, `newStorageSpotId` and `newExpirationDate` (`DateTime`).
  - `ProductRepository.moveProduct({productId, oldStorageSpotId, newStorageSpotId})` and `MoveProductUseCase`, both returning `Either<ProductFailure, MovedProduct>`.
  - `ProductRemoteDataSource.moveProduct` calls `dio.patch('/api/v1/products/$id/storage-spot', data: {'oldStorageSpotId': …, 'newStorageSpotId': …})`.
  - `MovedProductResponseModel` parses the 200 response.
  - `ProductRepositoryImpl` maps a `DioException` to a `ProductFailure` with spec 09's mapping, plus:
    - 400: the backend `detail`, or "This product couldn't be moved. Try again."
    - 500: "Something went wrong on the server. Try again later."
    - The AI case is a 400, so it gets the backend `detail` when there is one.
  - `MoveProductUseCase` is registered in `get_it` as a factory.
- **How a move starts:**
  - In selection mode, the AppBar shows a **Move** action next to Delete.
  - It's enabled only when **exactly one** product is selected and that product has a `storageSpotId`.
  - With a product that has no spot, it's disabled with the tooltip "This product has no storage spot".
- **The destination sheet** (a modal bottom sheet with two levels):
  - **Level 1, spaces:** every space from `SpacesBloc` that has at least one spot. The current space comes first, labelled "(current)". Each row shows the emoji, if there is one, and the name.
  - **Level 2, spots:** tapping a space shows its spots, each with its name and type label, under a header with ← back and the space's name. In the current space, the product's current spot is disabled and tagged "Current".
  - **Spaces not loaded:**
    - If `SpacesBloc` is initial or failed, the sheet dispatches `SpacesRequested` and shows a spinner.
    - If loading fails, the sheet shows the message and a **Retry** button.
    - If it's already loading, the sheet just shows the spinner.
  - Choosing a spot closes the sheet and returns the space and spot to the page. Dismissing the sheet does nothing.
- **Confirmation:** a dialog asks "Move *{product name}* to *{space} · {spot}*? Its expiration date will be recalculated." with **Cancel** and **Move**.
- **Moving:**
  - `SpaceOverviewBloc` handles `SelectedProductMoveSubmitted(destination)` and tracks it in a `ProductMoveStatus`: Idle, InProgress, Success or Failure.
  - While the move runs, a 24px spinner replaces the Move action, and the selection, row taps, ✕, Delete and back are all locked, the same as deletion.
- **Success** (updated locally, no refetch):
  - **Same space:** the product gets the new `storageSpotId` and `expirationDate`, and the list is re-sorted with the stable `_sortedByExpiration`.
  - **Another space:** the product is removed from the list.
  - Either way, the app leaves selection mode and shows the SnackBar "Moved to {space} · {spot}. New expiration date: {yyyy-MM-dd}".
- **Failure:** the app stays in selection mode with the same product selected and shows a SnackBar with the failure message.

**Out of scope (for future specs):**

- Moving several products at once. The endpoint moves one at a time, and a client-side loop would bring partial failures.
- Moving from the Edit product page (spec 10), or from anywhere other than the overview.
- Showing the old expiration date against the new one, or letting the user reject the recalculated date.
- Refreshing the Home spaces list or other screens after a move. The destination space's overview is loaded fresh when it's opened anyway.
- Giving a product with no storage spot a spot. The endpoint can't do that.
- Client-side timeouts or cancelling the move. `DioClient` sets no timeouts.
- Updating `SpacesBloc` when spots are renamed or removed elsewhere. A stale spot surfaces as the backend's error.

---

## Data model

### `products/domain/entities/`: new entity

```dart
// moved_product.dart
/// The result of `PATCH /api/v1/products/{id}/storage-spot`.
class MovedProduct extends Equatable {
  final String productId;
  final String newStorageSpotId;
  final DateTime newExpirationDate; // recalculated by the backend (AI)
}
```

### `products/data/`: model, data source, repository

- **`MovedProductResponseModel.fromJson(json)` → `toEntity()`:** it reads `productId`, `newStorageSpotId` and `newExpirationDate` (`yyyy-MM-dd`).
- **`ProductRemoteDataSource.moveProduct({productId, oldStorageSpotId, newStorageSpotId})`:**
  - It calls `dio.patch('/api/v1/products/$productId/storage-spot', data: {'oldStorageSpotId': …, 'newStorageSpotId': …})`.
  - It returns the response model.
- **`ProductRepository.moveProduct({required String productId, required String oldStorageSpotId, required String newStorageSpotId})`:**
  - It returns `Future<Either<ProductFailure, MovedProduct>>`.
  - It calls `_mapDioException` with the 400 message "This product couldn't be moved. Try again.". The backend `detail` wins when it's present, which covers the AI 400 case.
  - `_mapDioException` gets one new branch for **500**: "Something went wrong on the server. Try again later." It applies to update and delete too.
  - 401, 403, 409 and network failures keep spec 09's messages.
- **`MoveProductUseCase.call({productId, oldStorageSpotId, newStorageSpotId})`:** delegates to the repository.

### `space_overview/domain/entities/`: the chosen destination

```dart
// move_destination.dart
/// What the destination sheet returns. The names are only there for the
/// confirmation dialog and the SnackBar.
class MoveDestination extends Equatable {
  final String spaceId;
  final String spaceName;
  final String storageSpotId;
  final String storageSpotName;
}
```

### `space_overview`: new event and state

```dart
final class SelectedProductMoveSubmitted extends SpaceOverviewEvent {
  final MoveDestination destination;
}

sealed class ProductMoveStatus { const ProductMoveStatus(); }
final class ProductMoveIdle extends ProductMoveStatus { … }
final class ProductMoveInProgress extends ProductMoveStatus { … }
final class ProductMoveSuccess extends ProductMoveStatus {
  final MoveDestination destination;
  final DateTime newExpirationDate; // for the SnackBar
}
final class ProductMoveFailure extends ProductMoveStatus {
  final String message;
}

class SpaceOverviewState extends Equatable {
  // existing: status, selectedProductIds, deletionStatus
  final ProductMoveStatus moveStatus; // default ProductMoveIdle
  bool get isBusy; // deletion or move InProgress
}
```

**When `SelectedProductMoveSubmitted` is ignored:**
- The state isn't `SpaceOverviewLoadSuccess`.
- `isBusy` is true.
- The selection isn't exactly one id.
- The selected product has no `storageSpotId`.
- `destination.storageSpotId` equals the product's current spot.

**What the handler does:**
- It emits `ProductMoveInProgress` and calls `MoveProductUseCase` with the product's current spot as `oldStorageSpotId`.
- There's an `isClosed` guard after the `await`.
- On **Right**:
  - If `destination.spaceId == overview.id`, it replaces the product with a copy that has `storageSpotId = newStorageSpotId` and `expirationDate = newExpirationDate`, then applies `_sortedByExpiration`.
  - Otherwise, it removes the product from `productResults`.
  - Either way, it emits the new overview together with `selectedProductIds: {}` and `ProductMoveSuccess(destination, newExpirationDate)`.
- On **Left**, it emits `ProductMoveFailure(message)`, and the selection stays as it is.

**Changes to existing handlers:**
- The guards in `ProductSelectionToggled`, `ProductSelectionCleared` and `SelectedProductsDeleteSubmitted` switch from `_isDeleting` to `isBusy`.
- `SpaceOverviewRequested` also resets `moveStatus` to Idle.

`ProductMoveStatus` isn't `Equatable`, the same as the deletion status, so two failures in a row each show a SnackBar.

### `space_overview/presentation/widgets/`: the destination sheet

```dart
// move_destination_sheet.dart
Future<MoveDestination?> showMoveDestinationSheet(
  BuildContext context, {
  required String currentSpaceId,
  required String currentStorageSpotId,
});
```

- **Where the data comes from:** a `BlocBuilder<SpacesBloc, SpacesState>` over the app-wide `SpacesBloc`.
- **When it opens:** if the status is `initial` or `loadFailure`, it dispatches `SpacesRequested` once.
- **Rendering by status:**
  - `loading` shows a spinner.
  - `loadFailure` shows `errorMessage` and a **Retry** button, which dispatches `SpacesRequested`.
  - `loaded` shows the spaces.
- **Which space is open:** the only local state is the opened space. It's `null` on level 1 and set on level 2, and it's held in a `StatefulWidget`. It's pure navigation, with no business logic.
- **Ordering:** spaces with an empty `storageSpots` are hidden, and the current space is listed first.
- **Spot rows:** each shows `storageSpotName` with a `storageSpotTypeLabel(type)` subtitle. The spot equal to `currentStorageSpotId` is disabled and has a trailing "Current" tag.
- **Result:** tapping a spot pops the sheet with a `MoveDestination`, and dismissing it returns `null`.

---

## Implementation plan

Every step ends with `fvm flutter analyze` clean and `fvm flutter test` green.

1. **Products domain and data for move**
   - Add `MovedProduct`, `MovedProductResponseModel`, `ProductRemoteDataSource.moveProduct`, `ProductRepository.moveProduct` and `ProductRepositoryImpl.moveProduct`.
   - `_mapDioException` gets the new 500 branch.
   - Add `MoveProductUseCase`, registered in `get_it` as a factory.
   - Tests:
     - The repository:
       - Method, path, and a body with `oldStorageSpotId` and `newStorageSpotId`.
       - Parsing the 200 response, with the date as `yyyy-MM-dd`.
       - 400 with and without `detail`, including an "AI Server Error" body.
       - 401, 403 and 409.
       - 500 with and without `detail`.
       - A connection error.
     - One extra 500 test for update, since the new branch is shared.
     - The existing delete and update tests still pass.
   - Nothing uses the new code yet.

2. **`SpaceOverviewBloc` handles `SelectedProductMoveSubmitted`**
   - Add `MoveDestination`, `ProductMoveStatus`, `moveStatus` and `isBusy` to the state, and the event with its handler.
   - The existing guards switch from `_isDeleting` to `isBusy`.
   - Register the bloc's new `MoveProductUseCase` dependency in `get_it`.
   - Tests:
     - A move within the same space updates the spot and date and re-sorts the list, with a stable order for equal dates.
     - A move to another space removes the product.
     - Both leave selection mode and emit `ProductMoveSuccess` with the destination and date.
     - A failure keeps the selection and emits `ProductMoveFailure`.
     - The event is ignored when:
       - The state isn't `LoadSuccess`.
       - The selection isn't exactly one product.
       - The product has no spot.
       - The destination is the current spot.
       - A move or a deletion is in progress.
     - Toggle, clear and delete are ignored while moving.
     - The existing spec 06, 09 and 10 bloc tests still pass.

3. **The destination sheet**
   - Add `showMoveDestinationSheet` in `space_overview/presentation/widgets/move_destination_sheet.dart`.
   - Widget tests use a real `SpacesBloc` with a stub use case:
     - Level 1: spaces without spots are hidden, the current space comes first with "(current)", and the emoji and name are shown.
     - A tap on a space opens level 2 with its spots and type labels, and the current spot is disabled with "Current".
     - ← goes back to level 1.
     - A tap on a spot returns the `MoveDestination`, and dismissing the sheet returns `null`.
     - Spaces not loaded: with an `initial` status it dispatches `SpacesRequested` and shows a spinner, and a `loadFailure` shows the message, where Retry loads the spaces again.
   - Nothing opens the sheet yet.

4. **Move action on the overview**
   - Selection-mode AppBar:
     - Add a **Move** `IconButton` (`Icons.drive_file_move_outline`, tooltip "Move") before Delete.
     - It's enabled only when exactly one product is selected and that product has a spot. Otherwise it's disabled, with the tooltip "This product has no storage spot" when that's the reason.
     - While moving, a 24px spinner replaces it, and Delete and ✕ are disabled.
   - Flow: the sheet, then the confirmation dialog ("Move *{name}* to *{space} · {spot}*? Its expiration date will be recalculated." with Cancel and Move), then `SelectedProductMoveSubmitted`.
   - A `BlocListener` on `moveStatus`:
     - **Success** shows "Moved to {space} · {spot}. New expiration date: {yyyy-MM-dd}".
     - **Failure** shows the message.
     - Both call `hideCurrentSnackBar` first, the same as delete.
   - Back is blocked while moving, the same as while deleting.
   - Widget tests:
     - The Move action is visible only in selection mode, enabled with one selected product, disabled with two, and disabled with the tooltip for a product with no spot.
     - The full flow for the same space: the row moves and re-sorts, the SnackBar shows the new date, and selection mode ends.
     - The full flow to another space: the row disappears.
     - Cancel in the dialog, or dismissing the sheet, changes nothing and sends no request.
     - Failure keeps selection mode and shows the SnackBar.
     - The spinner shows, and taps and back are locked while moving.
     - The existing spec 09 and 10 page tests still pass.

---

## Acceptance criteria

**Starting a move**
- [ ] Outside selection mode, there's no Move action.
- [ ] In selection mode with exactly one product that has a storage spot, the Move action is enabled.
- [ ] With two or more products selected, the Move action is disabled.
- [ ] With one selected product that has no `storageSpotId`, the Move action is disabled and its tooltip is "This product has no storage spot".

**Destination sheet**
- [ ] Tapping Move opens a bottom sheet listing the user's spaces from `SpacesBloc`.
- [ ] Spaces with no storage spots aren't listed.
- [ ] The current space is listed first and labelled "(current)".
- [ ] Tapping a space shows its spots, each with its name and type label.
- [ ] ← returns to the space list.
- [ ] In the current space, the product's current spot is disabled and tagged "Current".
- [ ] If `SpacesBloc` is `initial` or `loadFailure` when the sheet opens, `SpacesRequested` is dispatched and a spinner is shown.
- [ ] A load failure shows the error message and a Retry button that reloads the spaces.
- [ ] Dismissing the sheet sends no request and leaves the selection unchanged.

**Confirmation**
- [ ] Choosing a spot shows "Move *{name}* to *{space} · {spot}*? Its expiration date will be recalculated." with Cancel and Move.
- [ ] Cancel sends no request and leaves the selection unchanged.

**Request**
- [ ] Move sends exactly one `PATCH /api/v1/products/{id}/storage-spot` with the body `{"oldStorageSpotId": <current spot>, "newStorageSpotId": <chosen spot>}`.

**While moving**
- [ ] A spinner replaces the Move action.
- [ ] Delete, ✕, row taps, long presses and system back do nothing.

**Success**
- [ ] A move within the same space updates the row's spot label and expiration date, and the list is re-sorted by expiration date, soonest first. Equal dates keep their order.
- [ ] A move to another space removes the row from the list.
- [ ] Either way, selection mode ends and a SnackBar shows "Moved to {space} · {spot}. New expiration date: {yyyy-MM-dd}".
- [ ] No overview refetch is made.

**Failure**
- [ ] The overview stays in selection mode with the same product selected.
- [ ] A SnackBar shows the backend `detail` when present. Otherwise it shows the default for the status:
  - 400: "This product couldn't be moved. Try again."
  - 401: "Your session has expired. Please log in again."
  - 403: "You are not allowed to perform this action."
  - 409: "You are not a participant of this space."
  - 500: "Something went wrong on the server. Try again later."
  - Network: "Network error. Please check your connection."
- [ ] Two failures in a row each show a SnackBar.

**Regression**
- [ ] Spec 09 selection and deletion, and spec 10 editing, behave as before.
- [ ] Update and delete failures with a 500 now show "Something went wrong on the server. Try again later.".
- [ ] `fvm flutter analyze` reports no issues, and `fvm flutter test` passes.

---

## Decisions taken and discarded

| Decision | Taken | Discarded | Why |
|---|---|---|---|
| **How a move starts** | A Move action in the selection-mode AppBar, only with exactly one product selected | A "Storage spot" row on the Edit product page; a ⋮ menu per row | It reuses spec 09's selection mode, and the endpoint moves one product at a time. Keeping it off the edit page avoids mixing an instant move with that page's deferred Save. |
| **Bulk move** | Not supported | A client-side loop over the selection | The endpoint is single-product. A loop would bring partial failures and several AI calls. |
| **Destination picker** | A bottom sheet with two levels: spaces, then their spots | One flat list of all spots; a full-screen page | The user's call. It stays short even with many spaces, and a sheet fits a quick pick. |
| **Where spaces come from** | The app-wide `SpacesBloc`, loaded when initial or failed | Fetch `GET /spaces` every time the sheet opens | The data is already in memory from Home. A stale spot shows up as the backend's error. |
| **Spaces without spots** | Hidden | Shown disabled | A product can't be moved there, so listing them adds nothing. |
| **Products without a spot** | The Move action is disabled with a tooltip | Let the user pick a spot for them | The endpoint needs `oldStorageSpotId` to match the current spot, so it can't assign a first spot. |
| **Confirmation** | A dialog warning that the expiration date will be recalculated | Move straight after picking | The backend changes the date through AI, so the user should know before it happens. |
| **After a move** | Local update: the same space updates the spot and date and re-sorts, another space removes the row | Refetch the overview | The user's call. It's consistent with specs 09 and 10 and saves a request. The response has everything needed. |
| **Success feedback** | A SnackBar with the destination and the new date (`yyyy-MM-dd`, like the rows) | Just "Product moved" | The date can change silently, so the SnackBar is where the user learns it. |
| **State management** | In `SpaceOverviewBloc`, with `ProductMoveStatus` mirroring the deletion status | A separate `MoveProductBloc` | The move acts on the overview's selection and list, just like delete. The sheet stays a stateless picker. |
| **Sheet navigation state** | A local `StatefulWidget` holding the opened space | A Cubit | It's pure UI navigation, with no business logic, so a Cubit would add ceremony for nothing. |
| **Same space or another space** | `destination.spaceId == overview.id` | Check whether the spot id is in `overview.storageSpots` | The destination already carries its space, so it's the most direct check. |
| **500 handling** | A new shared branch in `_mapDioException` | A move-only 500 message | Update and delete can also hit a 500. One message for all keeps it consistent. |
| **Client timeout** | None, keeping `DioClient` as it is | A longer receive timeout for the move | `DioClient` sets no timeouts, so a slow AI call isn't cut off. |

---

## Identified risks

- **A slow or failing AI recalculation.** The backend calls Ollama during the move, and it has no fallback.
  - *What happens:* the spinner can run for a long time, since there's no client timeout. If the backend fails, the user gets a 400 "AI Server Error" or a 500 and sees the SnackBar.
  - *Mitigation:* the overview stays locked with a clear spinner, and errors keep the selection so the user can retry. A timeout or cancel is out of scope.
- **Stale spaces or spots in `SpacesBloc`.** Spots may have been renamed or removed, or the user may have been removed from a space, since Home loaded.
  - *What happens:* the sheet shows old names, or the move fails with a 400 or 409, which is shown in the SnackBar.
  - *Mitigation:* none in this spec. Pull-to-refresh on Home refreshes `SpacesBloc`.
- **The product changed on the backend meanwhile.** Another participant may have moved or deleted it.
  - *What happens:* `oldStorageSpotId` no longer matches, or the product no longer exists, so the backend returns a 400 with "Business Rule Error" and the SnackBar shows it.
  - *Mitigation:* none. The overview isn't refetched.
- **Date and time zone.** `newExpirationDate` arrives as `yyyy-MM-dd`.
  - *What happens:* formatting it through UTC could shift the date shown by one day.
  - *Mitigation:* parse it with `DateTime.parse`, the same as the other product dates, and format it from `year`, `month` and `day`.
- **Not tested against the real backend.** As with specs 09 and 10, only a fake `HttpClientAdapter` checks the requests.
  - *Mitigation:* test manually against a running backend with Ollama: a move within the same space, a move to another space, and a move with Ollama stopped.
