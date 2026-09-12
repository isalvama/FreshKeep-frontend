# SPEC 05 — Capture and process a new shopping receipt

> **Status:** Implmeneted
> **Depends on:** SPEC 03 (create-space-storage-spots) — reuses the `Space`/`StorageSpot` domain entities for display; SPEC 04 (fetch-and-display-spaces-on-login) — the space picker reads `SpacesBloc.state.spaces`, already loaded on login; backend Shopping Receipt API (`POST /api/v1/spaces/{spaceId}/receipt-images`, documented in `api_contract.md`)
> **Date:** 2026-09-11
> **Objective:** Let an authenticated user pick one of their spaces and a single receipt photo from their device's photo library, upload it for AI extraction via `POST /api/v1/spaces/{spaceId}/receipt-images`, and review the extracted shopping-receipt data — including per-product selection for a later reprocess step — on a results screen whose "confirm"/"reprocess" actions are wired up in a following spec.

---

## Scope

**In:**

- **Entry point:** `CreationBottomSheet`'s second button renamed from "Add a New Receipt" to "Process a New Receipt" and enabled. Hidden entirely (not just disabled) whenever `SpacesBloc.state.spaces` is empty. Pressing it closes the bottom sheet and pushes the space-picker screen.
- **Screen 1 — Space picker** (`/process-receipt/space`): lists `SpacesBloc.state.spaces` (emoji + name, no new fetch). AppBar back button → `/home`. Selecting a space stores `spaceId` on `ShoppingReceiptBloc` and immediately invokes the native photo picker (`image_picker`, gallery source, single image, no custom gallery screen).
- **Native photo picker:** system UI, not an app route. Cancelling it leaves the user on the space-picker screen. Picking a file dispatches it into `ShoppingReceiptBloc` and pushes the confirm-image screen.
- **Screen 2 — Confirm image** (`/process-receipt/confirm-image`): shows the picked image full-size. Top-left back button pops this screen and immediately re-invokes the native picker (replacing the pending image on a new pick, leaving the user on the space picker if cancelled). Top-right "OK" button dispatches the upload/process event and pushes the processing screen.
- **Screen 3 — Processing** (`/process-receipt/processing`): loading indicator while `POST /api/v1/spaces/{spaceId}/receipt-images` is in flight (file + `language`, read from `WidgetsBinding.instance.platformDispatcher.locale.languageCode`).
- **Screen 4 — Error** (`/process-receipt/error`): shown on any processing failure. Displays a message specific to the failure type (400/401/403/409/422/429/500/network — see Data model). Single "OK" button → `context.go('/home')`.
- **Screen 5 — Results** (`/process-receipt/results`): renders `storeName`, `purchaseShoppingDate`, and the product list — AI-flagged products (`flaggedProducts`) shown first in a visually distinct (red-tinted) group, the rest below. Every product (flagged or not) has a checkbox for reprocess-selection, unchecked by default, that's fully interactive local state. An "OK" button and a "Reprocess selected products" button are both rendered but disabled (`onPressed: null`) — wiring them to `confirm`/`reprocess` is the next spec's job.
- **State:** new `ShoppingReceiptBloc` (app-root singleton via `service_locator.dart`, same scope as `SpacesBloc`/`CreateSpaceBloc`) holding `spaceId`, the picked image path, the extraction result, and the reprocess-selection set. Reset to initial whenever the flow is (re-)entered from the bottom sheet.
- **Failure hierarchy:** new `ShoppingReceiptFailure` sealed hierarchy in `core/errors/failures.dart`, mirroring `SpaceFailure`, with one subtype per distinct backend condition (validation/bad file, unauthorized, forbidden, conflict/not-a-participant, unprocessable-image, rate-limited, server, network) — each carrying its own user-facing message.

**Out of scope (deferred to later specs):**

- Wiring the "OK" (confirm) and "Reprocess selected products" buttons to `POST .../shopping-receipt/confirm` / `.../reprocess`, and the space-overview landing screen they navigate to — Spec 06.
- The "tap into a space" revisit flow backed by `GET /api/v1/spaces/{spaceId}/overview` outside the receipt-processing flow — a future spec.
- Editing any extracted field (name, date, price, storage spot, etc.) before confirm/reprocess — not requested.
- Multi-image receipts — the backend only accepts one file per receipt today.
- A custom in-app photo gallery — the native OS picker is used instead.

---

## Data model

New feature module: `lib/features/shopping_receipt/` (mirrors the backend's `modules/shopping_receipt`), reusing `Space`/`StorageSpot` from the existing `spaces` feature where the shape overlaps.

### Domain layer (`lib/features/shopping_receipt/domain/`)

```dart
// entities/product_extraction.dart
class ProductExtraction extends Equatable {
  final DateTime expirationDate;
  final String productName;
  final String? suggestedStorageSpotId; // null if the AI found no fitting spot
  final String productType;             // kept as raw String — no picker/edit UI in this spec
  final double? priceAmount;            // null if not shown on the receipt
  final String? currency;               // null if not shown on the receipt
}

// entities/receipt_extraction_result.dart
class ReceiptExtractionResult extends Equatable {
  final String receiptImageId;
  final List<StorageSpot> suggestedStorageSpots; // reused from spaces/domain/entities
  final DateTime purchaseShoppingDate;
  final String storeName;
  final List<ProductExtraction> productExtractions; // full list
  final List<ProductExtraction> flaggedProducts;     // AI-flagged subset of the above
}

// repositories/shopping_receipt_repository.dart
abstract class ShoppingReceiptRepository {
  Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>> processNewReceipt({
    required String spaceId,
    required String imagePath, // XFile.path from image_picker
    required String language,  // device languageCode, e.g. "es"
  });
}

// usecases/process_new_shopping_receipt_usecase.dart
class ProcessNewShoppingReceiptUseCase {
  final ShoppingReceiptRepository repository;
  const ProcessNewShoppingReceiptUseCase(this.repository);
  Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>> call({
    required String spaceId, required String imagePath, required String language,
  }) => repository.processNewReceipt(spaceId: spaceId, imagePath: imagePath, language: language);
}
```

### Data layer (`lib/features/shopping_receipt/data/`)

```dart
// models/product_extraction_response_model.dart — fromJson() + toEntity(), mirrors ProductExtraction
// models/receipt_extraction_response_model.dart — fromJson() + toEntity(), mirrors ReceiptExtractionResult;
//   suggestedStorageSpots parsed via the existing StorageSpotResponseModel from spaces/data/models

// datasources/shopping_receipt_remote_datasource.dart
class ShoppingReceiptRemoteDataSource {
  final Dio dio;
  const ShoppingReceiptRemoteDataSource(this.dio);

  Future<ReceiptExtractionResponseModel> processNewReceipt({
    required String spaceId, required String imagePath, required String language,
  }); // POST /api/v1/spaces/$spaceId/receipt-images as multipart: file + language
}

// repositories/shopping_receipt_repository_impl.dart
// processNewReceipt(): calls the datasource, maps DioException via _mapDioException
// (400→Validation, 401→Unauthorized, 403→Forbidden, 409→Conflict, 422→Unprocessable,
//  429→RateLimited, 500→Server, no response→Network), same shape as SpaceRepositoryImpl.
```

### Failures (`lib/core/errors/failures.dart` — appended, mirrors `SpaceFailure`)

```dart
sealed class ShoppingReceiptFailure {
  final String message;
  const ShoppingReceiptFailure(this.message);
}
class ShoppingReceiptValidationFailure extends ShoppingReceiptFailure { ... }   // 400
class ShoppingReceiptUnauthorizedFailure extends ShoppingReceiptFailure { ... } // 401
class ShoppingReceiptForbiddenFailure extends ShoppingReceiptFailure { ... }    // 403
class ShoppingReceiptConflictFailure extends ShoppingReceiptFailure { ... }     // 409 — not a participant
class ShoppingReceiptUnprocessableFailure extends ShoppingReceiptFailure { ... }// 422 — unreadable image
class ShoppingReceiptRateLimitedFailure extends ShoppingReceiptFailure { ... }  // 429
class ShoppingReceiptServerFailure extends ShoppingReceiptFailure { ... }       // 500
class ShoppingReceiptNetworkFailure extends ShoppingReceiptFailure { ... }      // no connectivity
```

### Presentation layer (`lib/features/shopping_receipt/presentation/bloc/shopping_receipt_bloc.dart`)

```dart
sealed class ShoppingReceiptStatus {}
final class ShoppingReceiptInitial extends ShoppingReceiptStatus {}
final class ShoppingReceiptProcessing extends ShoppingReceiptStatus {}
final class ShoppingReceiptProcessSuccess extends ShoppingReceiptStatus {
  final ReceiptExtractionResult result;
}
final class ShoppingReceiptProcessFailure extends ShoppingReceiptStatus {
  final String message; // failure.message, already resolved by the repository
}

class ShoppingReceiptState extends Equatable {
  final String? spaceId;
  final String? imagePath;
  final ShoppingReceiptStatus status;
  final Set<int> selectedForReprocess; // indices into result.productExtractions —
                                        // preview items carry no id until persisted
}

sealed class ShoppingReceiptEvent {}
final class ShoppingReceiptFlowReset extends ShoppingReceiptEvent {}      // dispatched on flow entry
final class SpaceForReceiptSelected extends ShoppingReceiptEvent { final String spaceId; }
final class ReceiptImagePicked extends ShoppingReceiptEvent { final String imagePath; }
final class ReceiptProcessingSubmitted extends ShoppingReceiptEvent {}    // reads device languageCode itself
final class ReprocessSelectionToggled extends ShoppingReceiptEvent { final int productIndex; }
```

`ShoppingReceiptBloc` is registered as an app-root singleton in `service_locator.dart`, same scope as `SpacesBloc`/`CreateSpaceBloc`. Navigation is page-level (`BlocListener` reacting to `state.status`, pushing the next route), never triggered from inside the bloc — same convention as `CreateSpaceBloc`/`NewSpacePage`.

---

## Implementation plan

1. Add the `image_picker` dependency to `pubspec.yaml`, and declare the required photo-library permissions (`NSPhotoLibraryUsageDescription` in `ios/Runner/Info.plist`; `READ_MEDIA_IMAGES`/`READ_EXTERNAL_STORAGE` in `android/app/src/main/AndroidManifest.xml`).
2. Add the `ShoppingReceiptFailure` sealed hierarchy to `lib/core/errors/failures.dart`, mirroring `SpaceFailure`.
3. Create the domain layer: `entities/product_extraction.dart`, `entities/receipt_extraction_result.dart`, `repositories/shopping_receipt_repository.dart`, `usecases/process_new_shopping_receipt_usecase.dart`. Manual test: `flutter analyze` passes (no implementations yet, just interfaces/entities).
4. Create the data layer: `ProductExtractionResponseModel`, `ReceiptExtractionResponseModel` (`fromJson`/`toEntity`), `ShoppingReceiptRemoteDataSource.processNewReceipt()`, `ShoppingReceiptRepositoryImpl` (with `_mapDioException` covering 400/401/403/409/422/429/500/network). Manual test: repository test mirroring `space_repository_impl_test.dart` — success mapping plus all eight failure-status cases.
5. Create `ShoppingReceiptBloc`/`ShoppingReceiptEvent`/`ShoppingReceiptState` (`part of` convention, like `spaces_bloc.dart`) and register it (plus the use case/repository/datasource) as a lazy singleton in `service_locator.dart`. Manual test: bloc test — `SpaceForReceiptSelected`/`ReceiptImagePicked` update state fields; `ReceiptProcessingSubmitted` emits `Processing` then `ProcessSuccess`/`ProcessFailure`; `ReprocessSelectionToggled` toggles set membership; `ShoppingReceiptFlowReset` returns to initial.
6. Add the five new routes to `app_router.dart`: `/process-receipt/space`, `/process-receipt/confirm-image`, `/process-receipt/processing`, `/process-receipt/error`, `/process-receipt/results`. Manual test: `flutter analyze` passes.
7. Build Screen 1 (space picker): lists `SpacesBloc.state.spaces`; tapping a space dispatches `SpaceForReceiptSelected` and invokes `image_picker`; a picked file dispatches `ReceiptImagePicked` and pushes the confirm-image screen; cancelling leaves the user on this screen unchanged. AppBar back button → `/home`.
8. Build Screen 2 (confirm image): full-size preview of the picked file. Back button pops this screen and re-invokes `image_picker` (new pick replaces the pending image and re-pushes this screen; cancelling leaves the user on Screen 1). "OK" dispatches `ReceiptProcessingSubmitted` and pushes the processing screen.
9. Build Screen 3 (processing): loading indicator; `BlocListener` on `ShoppingReceiptBloc` pushes the results screen on `ProcessSuccess`, or the error screen on `ProcessFailure`.
10. Build Screen 4 (error): shows the failure's message; single "OK" button → `context.go('/home')`.
11. Build Screen 5 (results): renders `storeName`/`purchaseShoppingDate`, `flaggedProducts` in a red-tinted group above the rest of `productExtractions`, a checkbox per product wired to `ReprocessSelectionToggled` (all unchecked initially), and the "OK"/"Reprocess selected products" buttons rendered disabled.
12. Wire the entry point: rename `CreationBottomSheet`'s second button to "Process a New Receipt", enable it, hide it entirely when `SpacesBloc.state.spaces` is empty; pressing it dispatches `ShoppingReceiptFlowReset`, closes the bottom sheet, and pushes `/process-receipt/space`.
13. Add widget tests for all five screens (space list + empty-hide, confirm-image back/OK, processing→success/failure navigation, error OK→home, results flagged-grouping + checkbox toggling + disabled buttons).
14. Run `flutter analyze` and `flutter test` for the full suite.

---

## Acceptance criteria

### Entry point

- [ ] `CreationBottomSheet`'s second button reads "Process a New Receipt" and is enabled.
- [ ] The button is not rendered at all when `SpacesBloc.state.spaces` is empty.
- [ ] Pressing it dispatches `ShoppingReceiptFlowReset`, closes the bottom sheet, and pushes `/process-receipt/space`.

### Space picker (Screen 1)

- [ ] Lists every space from `SpacesBloc.state.spaces` (emoji + name).
- [ ] Selecting a space stores `spaceId` on `ShoppingReceiptBloc` and invokes the native photo picker.
- [ ] Cancelling the native picker leaves the user on this screen with no error and no navigation.
- [ ] The AppBar back button navigates to `/home`.

### Confirm image (Screen 2)

- [ ] Displays the picked image at full size.
- [ ] The back button pops this screen and re-invokes the native picker; picking a new image replaces the pending one and re-pushes this screen; cancelling leaves the user on the space picker.
- [ ] "OK" dispatches `ReceiptProcessingSubmitted` and pushes the processing screen.

### Processing (Screen 3)

- [ ] Shows a loading indicator while `POST /api/v1/spaces/{spaceId}/receipt-images` is in flight.
- [ ] The request's `language` field is the device's `languageCode`.
- [ ] On success, navigates to the results screen.
- [ ] On failure, navigates to the error screen.

### Error (Screen 4)

- [ ] Shows a message specific to the failure type — 400/401/403/409/422/429/500/network each produce a distinct, correct message.
- [ ] "OK" navigates to `/home` via `context.go`, clearing the whole capture-flow stack.

### Results (Screen 5)

- [ ] Shows `storeName` and `purchaseShoppingDate`.
- [ ] `flaggedProducts` render in a visually distinct (red-tinted) group above the rest of `productExtractions`.
- [ ] Every product, flagged or not, has a checkbox — unchecked by default — that toggles local reprocess-selection state.
- [ ] The "OK" and "Reprocess selected products" buttons are rendered but disabled (`onPressed: null`).

### Data & repository

- [ ] `ShoppingReceiptRepositoryImpl.processNewReceipt()` maps a successful response to `Right(ReceiptExtractionResult)`.
- [ ] Maps 400/401/403/409/422/429/500/network failures to their corresponding `ShoppingReceiptFailure` subtype.

### Quality gates

- [ ] `flutter analyze` passes with no errors.
- [ ] `flutter test` passes, including the new repository tests, bloc tests, and widget tests for all five screens.

---

## Decisions

- **Yes:** Native `image_picker` over a custom in-app gallery for the photo-selection step. Standard UX, zero custom screen to build, permissions handled by the plugin itself.
- **Yes:** Loading (processing) and error are two separate GoRouter routes, not one combined status page like SPEC 03's `SpaceStatusPage`. Unlike SPEC 03, where success/failure were two views of the same narrow outcome, the error case here has no relation to the results screen's rich, interactive content.
- **Yes:** The error screen's "OK" does a full `context.go('/home')`, not a single `pop()` — by the time an error can occur, the user is several screens deep (space picker → confirm-image → processing).
- **Yes:** Confirm-image's back button re-invokes the native picker directly rather than popping to the space-picker screen. The native picker isn't a route, so there's no intermediate screen to land on; cancelling it naturally leaves the user on the previous route (the space picker), which already has its own way back to `/home`.
- **Yes:** `CreationBottomSheet`'s "Add a New Receipt" is renamed to "Process a New Receipt" and enabled in this spec, not deferred further. Nothing is "added" until confirm (Spec 06), and the new name matches the endpoint's own name (`processNewShoppingReceipt`).
- **Yes:** The button is hidden entirely (not just disabled) when `SpacesBloc.state.spaces` is empty. `GET /api/v1/spaces` only ever returns spaces the user participates in, so an empty list already means "no space to process a receipt into" — no separate participant check needed.
- **Yes:** Flagged products start unchecked, not pre-selected. Reprocessing is an explicit user opt-in, not something the AI's own low-confidence flag should force by default.
- **Yes:** "OK"/"Reprocess selected products" render disabled rather than being omitted from this spec. Matches the `CreationBottomSheet` precedent of shipping unwired UI disabled ahead of the spec that wires it.
- **Yes:** Per-product checkbox selection is fully interactive local state here, even with the consuming buttons disabled. The interaction itself doesn't depend on any network call, so there's no reason to defer it.
- **Yes:** A dedicated `ShoppingReceiptFailure` sealed hierarchy with one subtype per backend condition, mirroring `SpaceFailure`/`AuthFailure`, instead of one generic failure. The backend documents genuinely distinct conditions (422 "unreadable image" vs. 429 "rate limited") that deserve different user-facing messages.
- **Yes:** `productType`/`currency` stay raw `String` in `ProductExtraction`, unlike `StorageSpotType`'s dedicated enum. This spec has no editing/picker UI for these fields, only display — a 17-value enum purely for display would be premature.
- **Yes:** `language` is read directly inside `ShoppingReceiptBloc` via `WidgetsBinding.instance.platformDispatcher.locale.languageCode`, with no new core abstraction. The bloc is presentation layer and may depend on Flutter/`dart:ui`; only the domain/data layers must stay platform-agnostic.
- **Yes:** The domain repository takes a plain `String imagePath` rather than a Flutter-specific file type — keeps the domain layer framework-agnostic while the data layer can still trivially build a `MultipartFile` from it.
- **Yes:** `ShoppingReceiptBloc` is an app-root singleton (same scope as `SpacesBloc`/`CreateSpaceBloc`), reset via one `ShoppingReceiptFlowReset` event dispatched at flow entry — simpler than scattering reset logic across every possible exit path.
- **No:** Folding the space's full product catalog into the `confirm`/`reprocess` response, considered earlier in planning. Rejected in favor of the standalone `GET /api/v1/spaces/{spaceId}/overview` (built on the backend already) — keeps those endpoints' responses bounded to what they actually persisted.

---

## Risks

| Risk | Mitigation |
| --- | --- |
| `DioClient`'s shared `BaseOptions` hardcode `Content-Type: application/json` for every request; this is the first multipart (`FormData`) call in the app, and it's unverified whether Dio's per-request content-type override reliably wins over that base header in this setup. | Verify empirically in step 4's manual/repository test against a live-shaped fixture; if the header doesn't override cleanly, pass `Options(contentType: null)` on this specific request so Dio computes the multipart boundary header itself. |
| The device's reported `languageCode` could be a value the backend doesn't recognize (e.g. an unusual locale, or `"und"` on some platforms/emulators). | No client-side handling needed — the backend already documents a graceful fallback to English for unrecognized codes; send whatever `languageCode` the device reports. |
| `image_picker`'s permission-handling UX differs between iOS (limited-library-access picker) and Android (scoped `READ_MEDIA_IMAGES` on API 33+, `READ_EXTERNAL_STORAGE` below). | Manual end-to-end test on both platforms during step 7, not just one; the plugin handles the permission prompts itself, but the resulting picker UI genuinely differs. |
