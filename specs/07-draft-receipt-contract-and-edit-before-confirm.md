# SPEC 07 — Adapt the receipt flow to the draft-receipt contract and allow editing before confirm

> **Status:** Approved
> **Depends on:** SPEC 05 (pick-and-process-new-shopping-receipt) — extends `ReceiptExtractionResult`, `ProductExtraction` and the results screen it introduced; SPEC 06 (confirm-reprocess-and-space-overview) — changes the confirm/reprocess requests and `ShoppingReceiptBloc` state it introduced; backend Shopping Receipt API draft-receipt contract (`shoppingReceiptId` in the process response and the confirm/reprocess requests; `manuallyEditedExpirationDate` on every `ProductRequest`), documented in `api_contract.md`
> **Date:** 2026-09-29
> **Objective:** Send the draft `shoppingReceiptId` and a per-product `manuallyEditedExpirationDate` flag on confirm/reprocess, and let the user edit the shopping date, store name and product expiration dates on the results screen before confirming.

---

## Scope

**In:**

- **Draft-receipt contract — process:** `ReceiptExtractionResult` (and its response model) gains a required `shoppingReceiptId`, parsed from the first field of the `POST /api/v1/spaces/{spaceId}/receipt-images` response. A response missing it fails parsing, same as a missing `receiptImageId`.
- **Draft-receipt contract — confirm/reprocess:** both requests send `shoppingReceiptId` (read from `state.extraction`), and every serialized `ProductRequest` (in `allProducts` and `flaggedProducts`) carries `manuallyEditedExpirationDate`. No other request/response shape changes — confirm still omits `language`, reprocess still sends it, and the `PersistedShoppingReceipt` response is unchanged.
- **`ProductExtraction.manuallyEditedExpirationDate`:** new `bool` field on the domain entity, `false` for everything the AI extracted.
- **Results screen — editing (confirm only):**
  - **Shopping date:** calendar `IconButton` next to the date → `showDatePicker`, range `today − 1 year` … `today`.
  - **Store name:** pencil `IconButton` next to the name → `AlertDialog` with a `TextField`; value is trimmed, "Save" is disabled while blank; no max length.
  - **Product expiration date:** trailing calendar `IconButton` on every product row (flagged or not; the checkbox stays) → `showDatePicker`, range (current, possibly edited) shopping date … `today + 10 years`. A product counts as manually edited only while its chosen date differs from its originally extracted one; edited rows show an "edited" marker.
  - **Live shift preview:** when the shopping date is edited, every product that is *not* manually edited displays its expiration date shifted by the same number of days as the shopping-date change (mirroring the backend's confirm rectification). The wire request still sends those products' **original** extracted dates, so the backend's own shift isn't applied twice.
- **Confirm:** sends the edited `shoppingDate`/`storeName`, and per product either the original extracted date with `manuallyEditedExpirationDate: false` or the user-chosen date with `true`.
- **Reprocess:** always sends the **originally extracted** shopping date, store name, and product values, with `manuallyEditedExpirationDate: false` on every product — edits never reach reprocess. If any edit is pending, pressing "Reprocess selected products" first shows a confirmation dialog ("Reprocessing re-extracts the receipt with AI and discards your edits (shopping date, store name, expiration dates). Continue?"); "Cancel" keeps the edits and makes no call, "Continue" discards them and reprocesses. With no pending edits, no dialog.
- **Flagged-group fix:** the results screen stops finding flagged products by `Equatable` equality (which editing would break) and instead uses a set of flagged indices computed once when processing succeeds.
- Updating existing SPEC 05/06 repository, bloc and widget tests for the new fields and request shapes.

**Out of scope (for future specs):**

- Editing product name, type, price, currency or storage spot before confirm.
- Any editing on the reprocessed-results screen (Screen 6) — it stays read-only; the products are already persisted.
- Editing persisted products afterwards via `PATCH /api/v1/products/{id}` (e.g. from the space overview).
- Cleaning up abandoned DRAFT receipts (user leaves the flow after processing) — the backend exposes no delete/cancel-draft endpoint.
- Dedicated failure subtypes/messages for the new 400s (`NonExistentShoppingReceiptException`, `InvalidShoppingReceiptException`) — they keep mapping to the existing `ShoppingReceiptValidationFailure`.
- Making edits survive reprocess — would require the backend's reprocess to honor `manuallyEditedExpirationDate`.
- Space invitations, product move/delete, admin endpoints and the JWT `ROLE_` prefix change also documented in the updated `api_contract.md`.

---

## Data model

Extends `lib/features/shopping_receipt/` only. No new feature module, no new routes, no new failure types.

### Domain — entity changes

```dart
// entities/receipt_extraction_result.dart
class ReceiptExtractionResult extends Equatable {
  final String shoppingReceiptId;   // NEW — id of the server-side DRAFT receipt; first field of the process response
  final String receiptImageId;
  final List<StorageSpot> suggestedStorageSpots;
  final DateTime purchaseShoppingDate;
  final String storeName;
  final List<ProductExtraction> productExtractions;
  final List<ProductExtraction> flaggedProducts;
}

// entities/product_extraction.dart
class ProductExtraction extends Equatable {
  final DateTime expirationDate;
  final String productName;
  final String? suggestedStorageSpotId;
  final String productType;
  final double? priceAmount;
  final String? currency;
  final bool manuallyEditedExpirationDate; // NEW — constructor default `false`; included in props

  ProductExtraction copyWith({DateTime? expirationDate, bool? manuallyEditedExpirationDate}); // NEW
}
```

`ProductExtractionResponseModel` does **not** parse `manuallyEditedExpirationDate`. The process response doesn't contain it, so `toEntity()` leaves it at the default `false`. `ReceiptExtractionResponseModel.fromJson` reads `json['shoppingReceiptId'] as String`, which throws if the field is missing. `ShoppingReceiptRepositoryImpl.processNewReceipt` catches that parse error (`TypeError`/`FormatException`) and returns `ShoppingReceiptServerFailure` ("Unexpected response from the server"), so the flow ends on `ReceiptErrorPage` instead of an endless spinner. This covers any malformed process-response field, not just `shoppingReceiptId`; confirm/reprocess parsing is unchanged.

### Domain — shift rule

```dart
// domain/utils/expiration_date_shift.dart
/// Mirrors the backend's confirm rectification: shifts [original] by the
/// number of calendar days between [fromShoppingDate] and [toShoppingDate].
DateTime shiftExpirationDate({
  required DateTime original,
  required DateTime fromShoppingDate,
  required DateTime toShoppingDate,
});
```

Pure function with no Flutter imports. Days are counted as **calendar days**, built with `DateTime(y, m, d + delta)` rather than `Duration(days:)`, so DST changes can't move a date by an hour and then round it to the wrong day. The presentation layer uses it only for the **display preview**. It is never applied to request data (see "Wire rule" below).

### Domain/data — repository, use cases, datasource signatures

`confirmReceipt(...)` and `reprocessReceipt(...)` each gain `required String shoppingReceiptId`. The change goes through the whole chain: `ShoppingReceiptRepository` → `ShoppingReceiptRepositoryImpl` → `ConfirmShoppingReceiptUseCase` / `ReprocessShoppingReceiptUseCase` → `ShoppingReceiptRemoteDataSource`. The datasource writes it into the JSON body as `'shoppingReceiptId'`. Every other parameter stays the same.

```dart
// datasources/shopping_receipt_remote_datasource.dart — productRequestJson(...)
{
  'expirationDate': ...,
  'productName': ...,
  'suggestedStorageSpotId': ...,              // unchanged null → first-spot fallback
  'productType': ...,
  if (priceAmount != null) 'priceAmount': ...,
  if (currency != null) 'currency': ...,
  'manuallyEditedExpirationDate': product.manuallyEditedExpirationDate, // NEW — always present
}
```

Error mapping (`_mapDioException`) is unchanged. The two new 400 conditions map to the existing `ShoppingReceiptValidationFailure`.

### Presentation — bloc state changes

```dart
class ShoppingReceiptState extends Equatable {
  final String? spaceId;
  final String? imagePath;
  final ShoppingReceiptStatus status;
  final ReceiptExtractionResult? extraction;        // unchanged — stays the ORIGINAL, never mutated by edits
  final PersistedShoppingReceipt? reprocessedReceipt;
  final Set<int> selectedForReprocess;
  final int consecutiveFailureCount;

  final Set<int> flaggedIndices;                    // NEW — indices into extraction.productExtractions, computed once on ProcessSuccess
  final DateTime? shoppingDate;                     // NEW — current (possibly edited) value; seeded from extraction.purchaseShoppingDate on ProcessSuccess
  final String? storeName;                          // NEW — current (possibly edited) value; seeded from extraction.storeName on ProcessSuccess
  final Map<int, DateTime> editedExpirationDates;   // NEW — productIndex → user-chosen date; an entry exists only while it differs from the original

  bool get hasPendingEdits;                         // shoppingDate/storeName differ from extraction, or editedExpirationDates non-empty
  DateTime displayedExpirationDate(int index);      // edited date if present, else shiftExpirationDate(original, extraction.purchaseShoppingDate → shoppingDate)
}
```

Seeding `shoppingDate`/`storeName` with non-null values when processing succeeds keeps the existing `??`-based `copyWith` working. Discarding edits means resetting them to the extraction's values, never to `null`. `ShoppingReceiptFlowReset` still returns to `initial()`, which clears everything.

### Presentation — new bloc events (past tense)

```dart
final class ReceiptShoppingDateEdited extends ShoppingReceiptEvent { final DateTime shoppingDate; }
final class ReceiptStoreNameEdited extends ShoppingReceiptEvent { final String storeName; } // already trimmed, non-blank
final class ProductExpirationDateEdited extends ShoppingReceiptEvent {
  final int productIndex;
  final DateTime expirationDate;
}
```

- `ProductExpirationDateEdited` with a date equal to the product's original extracted date **removes** the map entry, so the product counts as not edited.
- `ReceiptReprocessSubmitted` (existing) now also **discards pending edits when submitted**. It resets `shoppingDate`/`storeName` to the extraction's values and empties `editedExpirationDates`, before emitting `Reprocessing`.

### Wire rule — what each call sends

| Field | Confirm | Reprocess |
| --- | --- | --- |
| `shoppingReceiptId` | `extraction.shoppingReceiptId` | `extraction.shoppingReceiptId` |
| `shoppingDate` | `state.shoppingDate` (edited) | `extraction.purchaseShoppingDate` (original) |
| `storeName` | `state.storeName` (edited) | `extraction.storeName` (original) |
| Product edited (index in `editedExpirationDates`) | chosen date, `manuallyEditedExpirationDate: true` | n/a — edits discarded |
| Product not edited | **original** extracted date, `manuallyEditedExpirationDate: false` (backend applies the shift) | original date, `false` |

The bloc builds the confirm `allProducts` with `product.copyWith(expirationDate: edited, manuallyEditedExpirationDate: true)` for each edited index. The datasource just serializes whatever it receives.

### Presentation — widgets (UI state only)

- `ReceiptResultsPage` reads `state.flaggedIndices` instead of the `flaggedProducts.toSet().contains(...)` equality check.
- `_StoreNameDialog` (private `StatefulWidget`): owns its `TextEditingController`, disables "Save" while the trimmed text is blank, and pops with the trimmed string. This is plain local form state with no API call, so it doesn't need a Cubit.
- Reprocess confirmation: `showDialog<bool>` in the page, shown only when `state.hasPendingEdits`. "Continue" dispatches `ReceiptReprocessSubmitted`.
- "Today" means `DateUtils.dateOnly(DateTime.now())`.

---

## Implementation plan

1. **Contract fields on entities/models.** Add `shoppingReceiptId` to `ReceiptExtractionResult` and `ReceiptExtractionResponseModel` (`fromJson`/`toEntity`). Add `manuallyEditedExpirationDate` (default `false`) and `copyWith(...)` to `ProductExtraction`. Make `productRequestJson` always emit `'manuallyEditedExpirationDate'`. Update the SPEC 05/06 test fixtures (process-response JSON, entity instances) to include `shoppingReceiptId`. Manual test: repository test — the process response maps `shoppingReceiptId`; a response without it fails; serialized products carry `manuallyEditedExpirationDate: false`.
2. **Thread `shoppingReceiptId` through confirm/reprocess.** Add `required String shoppingReceiptId` to `ShoppingReceiptRepository`, `ShoppingReceiptRepositoryImpl`, `ConfirmShoppingReceiptUseCase`, `ReprocessShoppingReceiptUseCase` and `ShoppingReceiptRemoteDataSource`, and write it into both JSON bodies. Make `_onConfirmSubmitted`/`_onReprocessSubmitted` pass `extraction.shoppingReceiptId`. Manual test: repository tests assert both request bodies contain `shoppingReceiptId`; bloc tests assert the use cases receive it. **After this step the existing flow works end-to-end against the updated backend again** (no editing yet).
3. **Shift rule.** Create `domain/utils/expiration_date_shift.dart` with `shiftExpirationDate(...)`. Manual test: unit tests — forward shift, backward shift, zero delta, month/year boundary, and a date range crossing a DST change stays at midnight on the correct day.
4. **Bloc state for review/editing.** Add `flaggedIndices`, `shoppingDate`, `storeName`, `editedExpirationDates`, `hasPendingEdits` and `displayedExpirationDate(int)` to `ShoppingReceiptState`. On `ProcessSuccess`, seed `shoppingDate`/`storeName` from the extraction and compute `flaggedIndices`. Switch `ReceiptResultsPage` from the `flaggedProducts.toSet().contains(...)` check to `state.flaggedIndices`, and display `state.shoppingDate`/`state.storeName`/`displayedExpirationDate(i)`. Manual test: bloc test for seeding and flagged indices; existing results-page widget tests still pass unchanged.
5. **Edit events.** Add `ReceiptShoppingDateEdited`, `ReceiptStoreNameEdited` and `ProductExpirationDateEdited` with their handlers. An edit back to the original date removes the map entry. Manual test: bloc tests — each event updates state; `hasPendingEdits` toggles correctly; `displayedExpirationDate` shifts unedited products and leaves edited ones as chosen.
6. **Confirm and reprocess use the wire rule.** `_onConfirmSubmitted` sends `state.shoppingDate`/`state.storeName` and builds `allProducts` with `copyWith(expirationDate: edited, manuallyEditedExpirationDate: true)` for edited indices and originals (flag `false`) for the rest. `_onReprocessSubmitted` resets edits to the extraction's values before emitting `Reprocessing`, then sends originals only. Manual test: bloc tests — confirm with a changed shopping date sends unedited products' **original** dates; edited products are sent with `true`; reprocess after edits sends only originals and leaves `hasPendingEdits` false.
7. **UI — shopping date and store name editing.** Next to the date, a calendar `IconButton` → `showDatePicker` (`today − 1 year` … `today`, with `initialDate` clamped into that range) → dispatches `ReceiptShoppingDateEdited`. Next to the name, a pencil `IconButton` → `_StoreNameDialog` (trimmed, "Save" disabled while blank) → dispatches `ReceiptStoreNameEdited`. Both icons are disabled while `Confirming`/`Reprocessing`. Manual test: widget tests — picker bounds, dialog Save disabled on blank/whitespace, dispatches the trimmed value, Cancel dispatches nothing.
8. **UI — product expiration date editing.** Add a trailing calendar `IconButton` on every product row (the checkbox stays leading) → `showDatePicker` (`state.shoppingDate` … `today + 10 years`, with `initialDate` clamped) → dispatches `ProductExpirationDateEdited`. Edited rows show an "edited" marker. Disabled while `Confirming`/`Reprocessing`. Manual test: widget tests — the icon opens a picker with the correct bounds; tapping the row still toggles the checkbox only; the marker appears for edited rows only; unedited rows show the shifted date after a shopping-date edit.
9. **UI — reprocess discard dialog.** When `state.hasPendingEdits`, pressing "Reprocess selected products" shows the confirmation dialog. "Continue" dispatches `ReceiptReprocessSubmitted`; "Cancel" dispatches nothing. With no pending edits, the event is dispatched directly as before. Manual test: widget tests for all three paths.
10. Run `flutter analyze` and `flutter test` on the full suite, and fix any stale SPEC 05/06 tests.

---

## Acceptance criteria

### Draft-receipt contract

- [ ] The process response's `shoppingReceiptId` is parsed into `ReceiptExtractionResult.shoppingReceiptId`; a response without it produces a failure, not a crash.
- [ ] The confirm request body contains `shoppingReceiptId` equal to the process response's value.
- [ ] The reprocess request body contains `shoppingReceiptId` equal to the process response's value.
- [ ] Every product in confirm's `allProducts` and in reprocess's `allProducts`/`flaggedProducts` has a `manuallyEditedExpirationDate` boolean.
- [ ] Confirm still omits `language`; reprocess still sends it.
- [ ] A 400 from confirm/reprocess (including `NonExistentShoppingReceiptException`/`InvalidShoppingReceiptException`) maps to `ShoppingReceiptValidationFailure` and follows the existing SnackBar → `ReceiptErrorPage` path.

### Editing on the results screen

- [ ] The shopping-date calendar icon opens a date picker whose selectable range is `today − 1 year` … `today`; no future date can be picked.
- [ ] The store-name pencil icon opens a dialog whose "Save" is disabled while the text is empty or whitespace-only; saving stores the trimmed value; "Cancel" changes nothing.
- [ ] Every product row (flagged or not) has a calendar icon that opens a date picker whose range is the current shopping date … `today + 10 years`.
- [ ] Tapping a product row (not the calendar icon) still only toggles its reprocess checkbox.
- [ ] A product whose chosen expiration date differs from its extracted date shows an "edited" marker; picking its original date again removes the marker.
- [ ] After editing the shopping date by N days, every non-edited product displays its extracted expiration date shifted by N days; edited products keep their chosen date.
- [ ] Flagged products stay in the red-tinted group after any edit.
- [ ] All edit icons are disabled while a confirm or reprocess request is in flight.
- [ ] A receipt whose extracted shopping or expiration date lies outside the picker's range opens the picker without an assertion error.

### Confirm with edits

- [ ] Confirm sends the edited `shoppingDate` and `storeName`.
- [ ] Edited products are sent with their chosen date and `manuallyEditedExpirationDate: true`.
- [ ] Non-edited products are sent with their **original extracted** date (not the displayed shifted date) and `manuallyEditedExpirationDate: false`.
- [ ] With no edits, confirm sends exactly the extracted values with every flag `false`.

### Reprocess with pending edits

- [ ] With pending edits, pressing "Reprocess selected products" shows the discard-confirmation dialog before any request is made.
- [ ] "Cancel" closes the dialog, keeps all edits, and makes no request.
- [ ] "Continue" discards all edits (displayed values revert to the extracted ones) and sends the reprocess request with only original values and every flag `false`.
- [ ] With no pending edits, pressing "Reprocess selected products" sends the request directly with no dialog.
- [ ] The reprocessed-results screen (Screen 6) has no editing controls.

### Shift rule

- [ ] `shiftExpirationDate` returns the correct date for forward, backward and zero shifts, across month/year boundaries, and across a DST change (always midnight, correct calendar day).

### Quality gates

- [ ] `flutter analyze` passes with no errors.
- [ ] `flutter test` passes, including new unit/bloc/widget tests and updated SPEC 05/06 tests.

---

## Decisions

- **Yes:** Editing (shopping date, store name, expiration dates) applies to **confirm only**. The backend's reprocess clamps a future shopping date to today and shifts **every** product's expiration date, ignoring `manuallyEditedExpirationDate` — sending edits there would silently overwrite them. Confirm honors the flag, so it's the only safe destination for manual edits.
- **Yes:** Reprocess with pending edits asks for confirmation and then discards them, rather than hard-locking editing vs. reprocess selection or discarding silently. No stuck states, and the user never loses work without being told.
- **Yes:** Edits are discarded when reprocess is **submitted**, not on its success. What's on screen always matches what was sent; the dialog already warned the edits would be lost.
- **Yes:** The shopping-date picker's upper bound is `today`. Confirm rejects future dates with a 400 instead of clamping, so blocking them in the UI prevents a guaranteed failure.
- **Yes:** Live shift preview on screen, while the request sends non-edited products' **original** dates. What the user sees matches what the backend stores, and the backend's own shift isn't applied twice.
- **Yes:** `extraction` stays immutable; edits live in separate state fields (`shoppingDate`, `storeName`, `editedExpirationDates`). Keeps the originals available for reprocess, the shift preview, "edit back to original" detection and discarding, without a second copy of the extraction.
- **Yes:** A product counts as manually edited only while its chosen date differs from the extracted one. Picking the original date again is the "undo", with no separate reset control.
- **Yes:** Flagged grouping uses indices computed once on process success, replacing the `Equatable`-equality lookup. Editing a product changes its equality, which would silently drop it out of the flagged group.
- **Yes:** `manuallyEditedExpirationDate` lives on the `ProductExtraction` entity (default `false`), not hardcoded in the serializer. It's the product's own state, and confirm needs it per product.
- **Yes:** `shiftExpirationDate` is a pure domain function using calendar-day arithmetic. It's a business rule mirroring the backend, it's unit-testable, and `Duration(days:)` would be off by an hour across DST changes.
- **Yes:** The store-name dialog is a private `StatefulWidget`, not a Cubit. Pure local form state with no API call and no cross-widget sharing.
- **Yes:** Expiration-date range is shopping date … `today + 10 years`; shopping-date range is `today − 1 year` … `today`. Wide enough for long-life products and older receipts, narrow enough to catch fat-finger picks.
- **No:** Editing name, type, price, currency or storage spot before confirm. Not requested; post-persistence editing via `PATCH /api/v1/products/{id}` can be its own spec.
- **No:** Dedicated failure subtypes for `NonExistentShoppingReceiptException`/`InvalidShoppingReceiptException`. The user can't act on them differently, and the existing 400 path already gives them a way out.
- **No:** Client-side cleanup of abandoned DRAFT receipts. The backend has no endpoint for it.
- **No (for now):** Making edits survive reprocess. That needs the backend's reprocess to honor `manuallyEditedExpirationDate`; revisit if the backend changes.

---

## Risks

| Risk | Mitigation |
| --- | --- |
| Device "today" can be ahead of the server's date (timezone/clock skew), so a shopping date picked as "today" may be a future date for the backend, and confirm returns 400. | No special handling: rare, and the existing SnackBar → `ReceiptErrorPage` path covers it. |
| `showDatePicker` asserts if `initialDate` is outside `[firstDate, lastDate]`, e.g. a receipt older than a year, or an AI-extracted expiration date earlier than the shopping date. | `initialDate` is clamped into the range before opening the picker (steps 7–8); covered by an acceptance criterion. |
| Moving the shopping date later can leave an already-edited expiration date before the new shopping date. | Accepted: the edited date is the user's explicit choice and the backend doesn't reject it. The picker's lower bound only applies to new picks. |
| The client's shift preview could drift from the backend's rectification logic if the backend changes it. | The preview is display-only: requests always send original dates for non-edited products, so persisted data stays correct even if the preview is wrong. `shiftExpirationDate`'s doc comment points to the backend contract section. |
| A confirm that succeeds server-side but times out client-side: the retry hits a finalized (no longer DRAFT) receipt and returns 400. | Accepted: it follows the existing failure path. The products are already persisted and visible in the space overview. |
| Abandoned flows leave DRAFT receipts on the server. | Out of scope, with no backend endpoint to delete them. Noted for a backend follow-up. |

---

## What is **not** in this spec

- Editing product name, type, price, currency or storage spot.
- Any editing on the reprocessed-results screen, or of persisted products (`PATCH /api/v1/products/{id}`).
- Edits surviving reprocess.
- Cleanup of abandoned DRAFT receipts.
- New failure subtypes for the draft-receipt 400s.
- Space invitations, product move/delete, admin endpoints, and the JWT `ROLE_` prefix change.

Each of these, if it lands, goes in its own spec.
