# SPEC 10 — Edit a product from a space's overview

> **Status:** Approved
> **Depends on:** SPEC 06 (confirm-reprocess-and-space-overview) — extends `SpaceOverviewBloc` and `SpaceOverviewPage`; SPEC 09 (delete-products-from-overview) — reuses `lib/features/products/`, `ProductRepository`, `ProductRemoteDataSource` and `ProductFailure`, and makes a tap outside selection mode open the editor. Uses the backend Product API: `PATCH /api/v1/products/{id}` (`api_contract.md`, "Product API Contract" §1).
> **Date:** 2026-09-30
> **Objective:** From a space's overview, the user can tap a product to open an edit page, change its name, expiration date, type, price amount and/or currency, and save only the changed fields to the backend, with the overview updated locally on success.

---

## Scope

**In:**

- **Products feature — domain and data (extends `lib/features/products/`):**
  - Enums in `products/domain/entities/`:
    - `ProductType`, with the 17 backend constants.
    - `Currency`, with the 42 backend constants, each carrying `displayName` and `symbol`.
    - `.name` is exactly the backend constant, and it's the only value ever sent.
  - `ProductChanges` is the input entity. It has nullable `name`, `expirationDate`, `productType`, `amount` and `currency`, and `null` means "unchanged".
  - `UpdatedProduct` is the result entity: `productId`, `name`, `expirationDate`, `productType`, `amount` and `currency`.
  - `ProductRepository.updateProduct({productId, changes})` and `UpdateProductUseCase`, both returning `Either<ProductFailure, UpdatedProduct>`.
  - `ProductRemoteDataSource.updateProduct` sends `dio.patch('/api/v1/products/$id', data: {...only non-null fields})`.
  - `UpdatedProductResponseModel` parses the 200 response, and `ProductRepositoryImpl` maps a `DioException` to a `ProductFailure`, reusing spec 09's mapping.
  - `UpdateProductUseCase` and `EditProductBloc` are registered in `get_it` as factories.
- **Route:** `/space-overview/:spaceId/products/:productId/edit`, with the `PersistedProduct` passed in `extra`.
- **How editing starts:**
  - Outside selection mode, tapping a product row opens the edit page.
  - Everything spec 09 does in the list is unchanged: long press still selects, and a tap in selection mode still toggles.
- **The edit page (`EditProductPage`):**
  - AppBar: a leading ✕, the title "Edit product", and a trailing "Save" action.
  - The fields are pre-filled with the product's current values:
    - **Name:** a `TextField`.
    - **Expiration date:** a read-only field that opens `showDatePicker`. Past dates are allowed.
    - **Type:** a `DropdownButtonFormField<ProductType>` with readable labels, e.g. `OTHER_FRESH_PRODUCTS` → "Other fresh products".
    - **Amount:** a numeric `TextField` that accepts `.` or `,` as the decimal separator.
    - **Currency:** a `DropdownButtonFormField<Currency>` with labels like "EUR — Euro (€)".
  - **Unknown values:** if the product's current `productType` or `currency` isn't in the enum, the dropdown starts with nothing selected and the hint "Unknown (VALUE)". That field is only sent if the user picks a value.
- **Validation (client-side, mirroring the backend):**
  - The name is trimmed, and must be non-empty and at most 30 characters.
  - The amount must be > 0.
  - If the product had no price, amount and currency must both be set or both be left empty.
  - If the product had a price, the amount can't be emptied. The API can't clear it.
  - Invalid fields show an inline error.
- **Save:**
  - Save is disabled while nothing has changed or any field is invalid.
  - The PATCH body contains only the fields whose value differs from the original.
- **Saving:** Save is replaced by a small spinner, the fields are disabled, and ✕ and back do nothing.
- **Success:**
  - The page closes with `context.pop(updatedProduct)`.
  - The overview dispatches `ProductUpdated(updatedProduct)` to `SpaceOverviewBloc`, which merges it into the matching product (keeping its `storageSpotId`) and re-sorts the list by `expirationDate`, soonest first.
  - A SnackBar shows "Product updated".
- **Failure:** the page stays open with the user's edits kept, and a SnackBar shows the failure message (the backend `detail` when present).
- **Leaving with unsaved changes:**
  - ✕ or system back opens a "Discard changes?" dialog with "Keep editing" and "Discard".
  - Without changes, the page closes right away.

**Out of scope (for future specs):**

- Moving a product to another storage spot (`PATCH /api/v1/products/{id}/storage-spot`).
- Clearing a product's price or currency. The API treats `null` as "unchanged".
- Editing several products at once.
- Refetching the overview after a save.
- Editing products from the receipt flow (spec 07 is unchanged).
- Localizing the type and currency labels.
- Any change to the overview endpoint, its model, or spec 09's delete behavior.

---

## Data model

### `products/domain/entities/`: new enums and entities

```dart
// product_type.dart
enum ProductType {
  FRUITS, VEGETABLES, OTHER_FRESH_PRODUCTS, MEAT, SEAFOOD, DAIRY, DELI,
  BAKERY, PANTRY, SNACKS, SWEETS, FROZEN_FOODS, ICE_CREAM_AND_DESSERTS,
  BEVERAGES, INTERNATIONAL, SAUCES, OTHER;

  /// `OTHER_FRESH_PRODUCTS` → "Other fresh products"
  String get label;
  /// null if [value] is not a known constant
  static ProductType? tryParse(String? value);
}

// currency.dart
enum Currency {
  USD('United States Dollar', r'$'), EUR('Euro', '€'), /* … all 42 … */
  RUB('Russian Ruble', '₽');

  const Currency(this.displayName, this.symbol);
  final String displayName;
  final String symbol;

  /// "EUR — Euro (€)"
  String get label;
  static Currency? tryParse(String? value);
}

// product_changes.dart — null = unchanged, never sent
class ProductChanges extends Equatable {
  final String? name;
  final DateTime? expirationDate;
  final ProductType? productType;
  final double? amount;
  final Currency? currency;
  bool get isEmpty; // true when every field is null
}

// updated_product.dart
class UpdatedProduct extends Equatable {
  final String productId;
  final String name;
  final DateTime expirationDate;
  final String productType;
  final double? amount;
  final String? currency;
}
```

The full `Currency` list, in backend order (constant, display name, symbol):

| Constant | Display name | Symbol |
|---|---|---|
| USD | United States Dollar | $ |
| EUR | Euro | € |
| GBP | British Pound | £ |
| JPY | Japanese Yen | ¥ |
| CHF | Swiss Franc | CHf |
| CAD | Canadian Dollar | C$ |
| AUD | Australian Dollar | A$ |
| NZD | New Zealand Dollar | NZ$ |
| SEK | Swedish Krona | kr |
| NOK | Norwegian Krone | kr |
| DKK | Danish Krone | kr |
| PLN | Polish Zloty | zł |
| CZK | Czech Koruna | Kč |
| HUF | Hungarian Forint | Ft |
| RON | Romanian Leu | lei |
| BGN | Bulgarian Lev | лв |
| MXN | Mexican Peso | $ |
| BRL | Brazilian Real | R$ |
| ARS | Argentine Peso | $ |
| CLP | Chilean Peso | $ |
| COP | Colombian Peso | $ |
| PEN | Peruvian Sol | S/ |
| UYU | Uruguayan Peso | $U |
| CNY | Chinese Yuan | ¥ |
| HKD | Hong Kong Dollar | HK$ |
| SGD | Singapore Dollar | S$ |
| INR | Indian Rupee | ₹ |
| KRW | South Korean Won | ₩ |
| THB | Thai Baht | ฿ |
| IDR | Indonesian Rupiah | Rp |
| MYR | Malaysian Ringgit | RM |
| PHP | Philippine Peso | ₱ |
| VND | Vietnamese Dong | ₫ |
| AED | UAE Dirham | د.إ |
| SAR | Saudi Riyal | ر.س |
| ILS | Israeli New Shekel | ₪ |
| TRY | Turkish Lira | ₺ |
| ZAR | South African Rand | R |
| EGP | Egyptian Pound | E£ |
| NGN | Nigerian Naira | ₦ |
| UAH | Ukrainian Hryvnia | ₴ |
| RUB | Russian Ruble | ₽ |

Only the constant name is ever sent to the backend — never the display name or the symbol.

- **Enum names:** the enum values keep the backend's `UPPER_SNAKE_CASE` names, so `.name` is the constant that gets sent. This needs a file-level `// ignore_for_file: constant_identifier_names`.
- **Raw strings in `UpdatedProduct`:** `productType` and `currency` stay as `String`, just like in `PersistedProduct`. That way an unknown value coming back from the backend never breaks parsing.

### `products/data/`: model, data source, repository

- **`UpdatedProductResponseModel.fromJson(json)` → `toEntity()`:**
  - It reads `productId`, `name`, `expirationDate` (`yyyy-MM-dd`), `productType`, `amount` (`num?` converted with `toDouble()`) and `currency`.
- **`ProductRemoteDataSource.updateProduct({productId, changes})`:**
  - It calls `dio.patch('/api/v1/products/$productId', data: body)`.
  - The body contains only the non-null fields:
    - `name`
    - `expirationDate` as `yyyy-MM-dd`
    - `productType` as the constant name
    - `amount`
    - `currency` as the constant name
  - It returns the response model.
- **`ProductRepository.updateProduct({required String productId, required ProductChanges changes})`:**
  - It returns `Future<Either<ProductFailure, UpdatedProduct>>`.
  - `_mapDioException` takes the default 400 message as a parameter.
    - Delete keeps its current text: "Some of these products no longer exist."
    - Update uses "This product couldn't be updated. Check the values and try again."
  - 401, 403, 409 and network failures keep spec 09's messages.
- **`UpdateProductUseCase.call({productId, changes})`:** delegates to the repository.

### `products/presentation/bloc/`: `EditProductBloc`

```dart
sealed class ProductSaveStatus { const ProductSaveStatus(); }
final class ProductSaveIdle extends ProductSaveStatus { … }
final class ProductSaveInProgress extends ProductSaveStatus { … }
final class ProductSaveSuccess extends ProductSaveStatus {
  final UpdatedProduct product; // page pops with it
}
final class ProductSaveFailure extends ProductSaveStatus {
  final String message;
}

class EditProductState extends Equatable {
  final PersistedProduct original;
  final String name;              // raw text, as typed
  final DateTime expirationDate;
  final ProductType? productType; // null = unknown original, untouched
  final String amountText;        // raw text, as typed
  final Currency? currency;       // null = none / unknown, untouched
  final ProductSaveStatus saveStatus;

  // Derived (pure getters, no widget logic):
  String? get nameError;     // "Name is required." / "Name must be at most 30 characters."
  String? get amountError;   // "Enter an amount greater than 0." / "The price can't be removed." / "Enter an amount."
  String? get currencyError; // "Choose a currency."
  ProductChanges get changes; // only fields that differ from [original]
  bool get hasChanges => !changes.isEmpty;
  bool get canSave;          // hasChanges && no errors && not InProgress
}
```

The initial state comes from the `PersistedProduct`:
- `amountText` is the price with trailing `.0` dropped (`2.5` → `"2.5"`, `3.0` → `"3"`), or `""` if there's no price.
- `productType` and `currency` are set with `tryParse`.

**When a field counts as changed:**

| Field | Counts as changed when |
|---|---|
| `name` | the trimmed text differs from `original.productName` |
| `expirationDate` | the date (compared without time) differs |
| `productType` | it's non-null and its `.name` differs from `original.productType` |
| `amount` | the parsed amount (`,` replaced by `.`) is valid and differs from `original.priceAmount` |
| `currency` | it's non-null and its `.name` differs from `original.currency` |

**Events (past tense):** `EditProductNameChanged(String)`, `EditProductExpirationDateChanged(DateTime)`, `EditProductTypeChanged(ProductType)`, `EditProductAmountChanged(String)`, `EditProductCurrencyChanged(Currency)` and `EditProductSaveSubmitted()`.

**What the bloc does:**
- Field events are ignored while the save is `InProgress`.
- `EditProductSaveSubmitted` is ignored unless `canSave` is true.
- Otherwise it emits `InProgress` and calls `UpdateProductUseCase`:
  - On **Right**, it emits `ProductSaveSuccess(product)`.
  - On **Left**, it emits `ProductSaveFailure(message)`, and the field values stay as they are.
- There's an `isClosed` guard after the `await`.
- `ProductSaveStatus` isn't `Equatable`, the same as in spec 09, so two failures in a row each show a SnackBar.

### `space_overview`: new event

```dart
final class ProductUpdated extends SpaceOverviewEvent {
  final UpdatedProduct product;
}
```

- **When it applies:** only in `SpaceOverviewLoadSuccess`. Otherwise it's ignored.
- **What it does:**
  - It replaces the product whose `id == product.productId` with a `PersistedProduct`. That product keeps the old `storageSpotId` and takes `productName`, `expirationDate`, `productType`, `priceAmount` and `currency` from the update.
  - It then sorts `productResults` by `expirationDate`, soonest first, keeping the existing order for equal dates.
- **Missing id:** if the id isn't in the list, nothing is emitted.

---

## Implementation plan

Every step ends with `fvm flutter analyze` clean and `fvm flutter test` green.

1. **Products domain and data for update**
   - Add the `ProductType` and `Currency` enums, with `label` and `tryParse`, plus the `ProductChanges` and `UpdatedProduct` entities.
   - Add `UpdatedProductResponseModel`, `ProductRemoteDataSource.updateProduct` (`dio.patch`, sending only non-null fields), `ProductRepository.updateProduct` and `ProductRepositoryImpl.updateProduct`.
   - `_mapDioException` gets a parameter for the default 400 message. Delete keeps its current message.
   - Add `UpdateProductUseCase`, registered in `get_it` as a factory.
   - Tests:
     - The enums: 17 and 42 values, `label` examples, and `tryParse` for known, unknown and null values.
     - The repository:
       - Method, path and body for full and partial changes: date as `yyyy-MM-dd`, constant names, and null fields left out.
       - Parsing the 200 response, including null `amount` and `currency`.
       - 400, 401, 403 and 409, each with and without `detail`.
       - A connection error.
     - The existing delete tests still pass.
   - Nothing uses the new code yet.

2. **`EditProductBloc`**
   - Add the state (with its derived validation, `changes` and `canSave`), the events and the bloc, registered in `get_it` as a factory.
   - Tests:
     - Initial state from a `PersistedProduct`, both with and without a price, and with an unknown type or currency.
     - Each validation message.
     - The pairing rule for amount and currency when the product has no price.
     - The rule that an existing price can't be removed.
     - `changes` contains only the fields that changed. A trimmed name equal to the original isn't a change, and `,` works as the decimal separator.
     - Submit is ignored when `canSave` is false.
     - Success and failure, including retrying after a failure.
     - Field events and submit are ignored while saving.

3. **`SpaceOverviewBloc` handles `ProductUpdated`**
   - Add the event and its handler: merge the update into the matching product (keeping `storageSpotId`), re-sort by `expirationDate`, and ignore the event when the state isn't `LoadSuccess` or the id isn't in the list.
   - Tests:
     - The merge, and that `storageSpotId` is kept.
     - Re-sorting when the date changes.
     - An unknown id emits nothing.
     - The event is ignored while loading or after a load failure.
     - The existing spec 06 and spec 09 bloc tests still pass.

4. **`EditProductPage` and its route**
   - Add the route `/space-overview/:spaceId/products/:productId/edit`, with the `PersistedProduct` in `extra`, and the page itself:
     - An AppBar with ✕, the title "Edit product" and a "Save" action. Save is replaced by a spinner while saving.
     - The five pre-filled fields, with inline errors.
     - Fields disabled while saving.
     - A `BlocListener`: on success it calls `context.pop(product)`, and on failure it shows a SnackBar.
     - A `PopScope`:
       - Back does nothing while saving.
       - With unsaved changes, back opens "Discard changes?" with "Keep editing" and "Discard".
       - Otherwise, back closes the page.
   - Widget tests:
     - Pre-filled values, including the "Unknown (VALUE)" hint.
     - Save is disabled until something changes.
     - Inline errors.
     - Save sends only the changed fields (checked with a recording repository).
     - The spinner, and that the fields are disabled while saving.
     - The failure SnackBar, with the edits kept.
     - Success pops with the `UpdatedProduct`.
     - The discard dialog: Keep editing stays, Discard leaves, and with no changes the page leaves without asking. Checked for both ✕ and system back.
   - The page can only be reached through the route at this point.

5. **Open the editor from the overview**
   - In `_OverviewProductTile`, outside selection mode, `onTap` runs `context.push<UpdatedProduct>(...)`.
   - When a non-null result comes back and the widget is still mounted, the page dispatches `ProductUpdated` and shows the "Product updated" SnackBar.
   - In selection mode, tap still toggles, and long press is unchanged.
   - Widget tests:
     - A tap outside selection mode opens the editor.
     - Saving comes back to the overview with the row updated and re-sorted, and the SnackBar shown.
     - Closing without saving leaves the list unchanged and shows no SnackBar.
     - In selection mode, a tap still toggles the row and doesn't open the editor.
     - The existing spec 09 selection and deletion tests still pass.

---

## Acceptance criteria

**Opening the editor**
- [ ] Outside selection mode, tapping a product row on the overview opens "Edit product" at `/space-overview/:spaceId/products/:productId/edit`.
- [ ] In selection mode, tapping a row toggles it and doesn't open the editor. A long press behaves exactly as in spec 09.

**The form**
- [ ] The name, expiration date, type, amount and currency are pre-filled from the product.
- [ ] The Type dropdown lists exactly the 17 `ProductType` constants with readable labels, e.g. "Other fresh products".
- [ ] The Currency dropdown lists exactly the 42 `Currency` constants, labeled "CODE — Display name (symbol)".
- [ ] A product whose `productType` or `currency` isn't a known constant shows that dropdown empty, with the hint "Unknown (VALUE)".
- [ ] The expiration date is chosen with a date picker, and past dates can be picked.

**Validation**
- [ ] A name that's empty after trimming shows "Name is required.", and one longer than 30 characters shows "Name must be at most 30 characters."
- [ ] An amount that's non-numeric, `0` or negative shows "Enter an amount greater than 0." Both `2.5` and `2,5` are accepted.
- [ ] For a product with a price, emptying the amount shows "The price can't be removed."
- [ ] For a product without a price:
  - An amount with no currency shows "Choose a currency."
  - A currency with no amount shows "Enter an amount."
  - Leaving both empty is valid.
- [ ] Save is disabled while nothing has changed or while any field shows an error.

**Request**
- [ ] Save sends `PATCH /api/v1/products/{id}` with only the changed fields:
  - Name trimmed.
  - Date as `yyyy-MM-dd`.
  - `productType` and `currency` as constant names, never a label, display name or symbol.
  - `amount` as a number.
- [ ] A field whose trimmed value is equal to the original isn't sent. An unknown type or currency the user didn't touch isn't sent either.

**Saving**
- [ ] While saving, Save is replaced by a spinner, the fields are disabled, and ✕ and system back do nothing.
- [ ] On success, the page closes and the overview shows the updated values without refetching. The product keeps its storage spot, the list is re-sorted by expiration date (soonest first), and a SnackBar shows "Product updated".
- [ ] On failure, the page stays open with the edits kept, and a SnackBar shows the backend `detail`. Without one, it shows the default message for that status:

  | Status | Message |
  |---|---|
  | 400 | "This product couldn't be updated. Check the values and try again." |
  | 401 | "Your session has expired. Please log in again." |
  | 403 | "You are not allowed to perform this action." |
  | 409 | "You are not a participant of this space." |
  | network error | "Network error. Please check your connection." |

- [ ] Saving again after a failure sends the request again.

**Leaving the page**
- [ ] With no changes, ✕ and system back close the editor right away. The overview is unchanged and no SnackBar is shown.
- [ ] With unsaved changes, ✕ and system back open "Discard changes?":
  - "Keep editing" stays on the page with the edits kept.
  - "Discard" closes the page, and the overview is unchanged.

**Regression**
- [ ] Deleting products (spec 09) behaves exactly as before, and its default 400 message is still "Some of these products no longer exist."
- [ ] `fvm flutter analyze` reports no issues, and `fvm flutter test` passes.

---

## Decisions taken and discarded

| Decision | Taken | Discarded | Why |
|---|---|---|---|
| **How editing starts** | Tap a row outside selection mode | An edit icon per row; both | Tap was unused outside selection mode and doesn't clash with spec 09's long press. There's no extra icon to fit in every row. |
| **Editor surface** | Full-screen page with its own route | Bottom sheet; `AlertDialog` | Five fields plus a date picker are too many for a dialog, and a page handles the keyboard better on mobile. |
| **Type and currency input** | Dropdowns from Dart enums that mirror the backend constants | Free text; values seen in the space plus free text | Invalid values can't be entered. `.name` is exactly the constant the backend accepts, so labels, display names and symbols are never sent. |
| **Enum naming** | Keep the backend's `UPPER_SNAKE_CASE` names (with `ignore_for_file: constant_identifier_names`) | `lowerCamelCase` plus a mapping table | The names map one-to-one to the constants, so there's no mapping to keep in sync. |
| **PATCH body** | Only the changed fields; Save disabled when nothing changed | Always send all five fields | The body stays minimal and can't accidentally overwrite values, which fits a partial-update API. |
| **Unknown type or currency** | Empty dropdown with the hint "Unknown (VALUE)", sent only if the user picks a value | Block editing; force a choice | Products with old data can still be edited without the user being forced to reclassify them. |
| **Price rules** | A new price needs both amount and currency; an existing price can't be emptied | Allow a partial price; allow clearing | The user's call for the pairing rule. The API treats `null` as "unchanged", so the price can't be cleared. |
| **Where the code lives** | `lib/features/products/` (domain, data, `EditProductBloc`, page) | A new feature folder; inside `space_overview` | Products already own spec 09's repository and failures, so the update belongs there. |
| **State management** | A new `EditProductBloc`; the result goes back through `context.pop` and a small `ProductUpdated` event | Put editing into `SpaceOverviewBloc` | The form state stays scoped to the editor, and `SpaceOverviewBloc`, already large after spec 09, gains only one event. |
| **After a save** | Merge the update into the list locally, keep `storageSpotId`, re-sort | Refetch the overview | This matches spec 09 (no refetch) and saves a request. The response doesn't include `storageSpotId`, so the value from the list is kept. |
| **Validation location** | Derived getters on `EditProductState` | Validators in the widgets | CLAUDE.md says widgets must never contain business logic. |
| **Leaving with unsaved changes** | "Discard changes?" confirmation | Leave silently | The user's call: edits aren't lost by accident. |
| **Default 400 message** | The message becomes a parameter: update gets its own text, delete keeps spec 09's | Share one generic 400 message | "Some of these products no longer exist." would be misleading for an update. |

---

## Identified risks

- **The enums can drift from the backend.** If the backend adds, renames or removes a `ProductType` or `Currency` constant, the dropdowns won't know.
  - *What happens:* a new constant can't be picked in the app. A removed one gets a 400 with a "Business Rule Error" message shown in the SnackBar.
  - *Mitigation:* the enum tests pin the value counts (17 and 42), and the "Unknown (VALUE)" hint keeps products with unknown values editable.
- **Comparing prices as doubles.** Checking whether the amount changed means comparing doubles, and backend values like `2.50` are parsed as `2.5`.
  - *What happens:* rounding could make Save look enabled when nothing changed, or the other way round.
  - *Mitigation:* compare the parsed double with `priceAmount` from the same JSON decoding, and test values like `2.5` vs `2.50` and `3` vs `3.0`.
- **Date and time zone.** The date picker returns a local `DateTime`, and it's serialized as `yyyy-MM-dd`.
  - *What happens:* converting to UTC could shift the date by one day.
  - *Mitigation:* format the date from its `year`, `month` and `day` without converting to UTC, and compare dates without the time.
- **The product changed on the backend meanwhile.** Another participant may have deleted or edited the product since the overview loaded.
  - *What happens:* a delete gives a 400, whose message is shown in the SnackBar. An edit by someone else is silently overwritten for the fields sent, which is last-write-wins.
  - *Mitigation:* none in this spec. The overview isn't refetched after saving.
- **Not tested against the real backend.** As with spec 09, only a fake `HttpClientAdapter` checks the requests, so the real backend may behave differently.
  - *Mitigation:* test manually against a running backend: a full edit, a partial edit, an invalid type, and a price on a product that had none.
