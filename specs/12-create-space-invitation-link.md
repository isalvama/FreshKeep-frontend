# SPEC 12 — Create a space invitation link

> **Status:** Approved
> **Depends on:**
> - SPEC 03 (create-space-storage-spots): extends `lib/features/spaces/`, including `SpaceRepository`, `SpaceRemoteDataSource` and `SpaceFailure`.
> - SPEC 08 (open-space-overview-from-home): adds an action to the space overview's AppBar.
> - SPEC 09 (delete-products-from-overview): the Invite action shows only in the normal AppBar, not in selection mode.
> - The backend Space API, `POST /api/v1/spaces/{spaceId}/invitations` (`api_contract.md`, "Space API Contract" §4).
>
> **Date:** 2026-09-30
> **Objective:** From a space's overview, the user can create an invitation for that space and copy or share it as a `freshkeep://join?token=<token>` link, valid for 24 hours.

---

## Scope

**In:**

- **Spaces feature, domain and data** (extends `lib/features/spaces/`):
  - A `SpaceInvitation` entity with `id`, `token`, `spaceId` and `expiresAt` (`DateTime`, UTC).
  - `SpaceRepository.createInvitation({spaceId})` and `CreateSpaceInvitationUseCase`, both returning `Either<SpaceFailure, SpaceInvitation>`.
  - `SpaceRemoteDataSource.createInvitation` calls `dio.post('/api/v1/spaces/$spaceId/invitations')`, with no body.
  - `SpaceInvitationResponseModel` parses the 201 response. `expiresAt` has no timezone offset, so it's read as **UTC**.
  - `SpaceRepositoryImpl` maps a `DioException` with the existing `_mapDioException`, plus a new 409 branch:
    - 409 becomes a new `SpaceConflictFailure`: the backend `detail`, or "You're not a participant of this space."
  - `CreateSpaceInvitationUseCase` is registered in `get_it` as a factory.
- **Building the link:**
  - A constant `kInvitationLinkBase = 'freshkeep://join'` in `lib/core/constants/`.
  - The link is `freshkeep://join?token=<token>`, with the token URL-encoded.
- **Starting it (the overview AppBar):**
  - An **Invite** action (`Icons.person_add_alt_1`, tooltip "Invite") in the overview's normal AppBar.
  - It shows only when the overview is **loaded**, and never in selection mode.
- **Creating it:**
  - A new `SpaceInvitationBloc` in `lib/features/spaces/presentation/bloc/`, provided by the overview page. It handles `SpaceInvitationRequested(spaceId)`.
  - Its state is a `SpaceInvitationStatus`: `initial`, `inProgress`, `success` or `failure`, plus the invitation or the error message.
  - Every tap creates a **new** invitation. Nothing is cached or reused.
  - While the request runs, a 24px spinner replaces the Invite action, and more taps are ignored. Nothing else on the page is locked.
- **Success (the dialog):**
  - Title "Invite to {space name}".
  - The link as selectable text.
  - "Expires {yyyy-MM-dd HH:mm}" in the phone's local time.
  - Three buttons:
    - **Copy** puts the link on the clipboard and shows a "Link copied" SnackBar.
    - **Share** opens the share sheet (`share_plus`) with the text "Join my space {space name} on Fresh Keep: {link}".
    - **Close** closes the dialog.
- **Failure:** a SnackBar with the failure message, and the Invite action is enabled again.
- **Dependency:** the `share_plus` package is added to `pubspec.yaml`.

**Out of scope (for future specs):**

- **Joining a space from the link.** That covers registering the `freshkeep` scheme on Android and iOS, the go_router route that receives it, and calling `POST /api/v1/spaces/invitations/{token}/join`. Until then, tapping the link doesn't open the app.
- **An https redirect page** (for example on GitHub Pages), so the link becomes tappable in WhatsApp and other messaging apps.
- Inviting from anywhere other than the overview, such as the Home space cards.
- Listing, reusing, revoking or expiring invitations early. The backend has no endpoint for any of that.
- Showing who joined with an invitation, or any participant management.
- Sending the invitation to a specific person, such as by email or a contact picker. The share sheet leaves that to the phone.

---

## Data model

### Domain: `lib/features/spaces/domain/entities/space_invitation.dart`

```dart
class SpaceInvitation extends Equatable {
  final String id;
  final String token;
  final String spaceId;
  final DateTime expiresAt; // UTC

  const SpaceInvitation({
    required this.id,
    required this.token,
    required this.spaceId,
    required this.expiresAt,
  });

  @override
  List<Object?> get props => [id, token, spaceId, expiresAt];
}
```

The backend's `userCreatorId` and `isActive` aren't kept. `isActive` is always `true` when an invitation is created, and nothing in this spec uses who created it.

### Repository and use case

```dart
// SpaceRepository (lib/features/spaces/domain/repositories/space_repository.dart)
Future<Either<SpaceFailure, SpaceInvitation>> createInvitation({
  required String spaceId,
});

// lib/features/spaces/domain/usecases/create_space_invitation_usecase.dart
class CreateSpaceInvitationUseCase {
  final SpaceRepository repository;
  const CreateSpaceInvitationUseCase(this.repository);

  Future<Either<SpaceFailure, SpaceInvitation>> call({required String spaceId}) =>
      repository.createInvitation(spaceId: spaceId);
}
```

### Data: `lib/features/spaces/data/models/space_invitation_response_model.dart`

```dart
class SpaceInvitationResponseModel {
  final String id;
  final String token;
  final String spaceId;
  final DateTime expiresAt;

  factory SpaceInvitationResponseModel.fromJson(Map<String, dynamic> json);
  // expiresAt: "2026-09-29T21:00:00" (no offset) → parsed as UTC:
  // DateTime.parse('${json['expiresAt']}Z')

  SpaceInvitation toEntity();
  factory SpaceInvitationResponseModel.fromEntity(SpaceInvitation invitation);
}
```

`SpaceRemoteDataSource.createInvitation(String spaceId)` returns `Future<SpaceInvitationResponseModel>`.

### Failure: `lib/core/errors/failures.dart`

```dart
class SpaceConflictFailure extends SpaceFailure {
  const SpaceConflictFailure(super.message); // 409 — not a participant
}
```

### Constant: `lib/core/constants/invitation_constants.dart`

```dart
const kInvitationLinkBase = 'freshkeep://join';
```

### The link (a pure function next to the constant)

```dart
String invitationLink(String token) =>
    '$kInvitationLinkBase?token=${Uri.encodeQueryComponent(token)}';
```

### Presentation: `lib/features/spaces/presentation/bloc/space_invitation_*.dart`

```dart
// space_invitation_event.dart
final class SpaceInvitationRequested extends SpaceInvitationEvent {
  final String spaceId;
}

// space_invitation_state.dart
enum SpaceInvitationStatus { initial, inProgress, success, failure }

class SpaceInvitationState extends Equatable {
  final SpaceInvitationStatus status;
  final SpaceInvitation? invitation;   // set on success
  final String? errorMessage;          // set on failure
}
```

- `SpaceInvitationBloc` ignores a `SpaceInvitationRequested` while its status is `inProgress`.
- Two failures in a row with the same message are equal states, so the page's listener wouldn't fire the second time. To avoid that, the bloc emits `inProgress` before every result.
- The same goes for success: every invitation has a new `id` and `token`, so every success is a new state.

No persistence: invitations exist only in memory while the dialog is open.

---

## Implementation plan

1. **Domain and data** (`lib/features/spaces/`, `lib/core/errors/failures.dart`, DI)
   - Add the `SpaceInvitation` entity, `SpaceConflictFailure`, and the `createInvitation` method on `SpaceRepository`.
   - Add `CreateSpaceInvitationUseCase`.
   - Add `SpaceInvitationResponseModel` with `fromJson` (`expiresAt` read as UTC), `toEntity` and `fromEntity`.
   - Add `SpaceRemoteDataSource.createInvitation`, which calls `POST /api/v1/spaces/$spaceId/invitations`.
   - `SpaceRepositoryImpl.createInvitation` reuses `_mapDioException`. The mapper gets a 409 → `SpaceConflictFailure` branch, which also applies to the existing space calls.
   - Register `CreateSpaceInvitationUseCase` in `get_it` as a factory.
   - Give the fake `SpaceRepository`s in existing tests a `createInvitation` stub.
   - **Tests:**
     - Model parsing, including `expiresAt` as UTC.
     - The repository's success and each failure: 400, 401, 403, 409 (with and without `detail`), 500 and network.
   - **Check:** analyze is clean and all tests pass.

2. **Link and bloc** (`lib/core/constants/`, `lib/features/spaces/presentation/bloc/`, DI)
   - Add `invitation_constants.dart` with `kInvitationLinkBase` and `invitationLink(token)`.
   - Add `SpaceInvitationBloc` with its events and state as `part` files:
     - It emits `inProgress`, then `success` or `failure`.
     - It ignores requests while `inProgress`.
     - It guards with `isClosed` after the await.
   - Register the bloc in `get_it` as a factory.
   - **Tests:**
     - `invitationLink` builds the right link and encodes the token.
     - Bloc tests: success, failure, a second request ignored while one is in progress, and two failures in a row each reaching the listener.
   - **Check:** analyze is clean and all tests pass. Nothing is visible in the UI yet.

3. **Invitation dialog** (`lib/features/spaces/presentation/widgets/space_invitation_dialog.dart`, `pubspec.yaml`)
   - Add `share_plus` to `pubspec.yaml`.
   - Add `showSpaceInvitationDialog(context, {spaceName, invitation})`:
     - It shows the title, the selectable link, and "Expires {yyyy-MM-dd HH:mm}" in local time.
     - **Copy** puts the link on the clipboard and shows the "Link copied" SnackBar.
     - **Share** opens the share sheet with the message.
     - **Close** closes the dialog.
   - For testing, the share call is passed in as an optional `onShare(String text)` parameter. By default it calls `share_plus`.
   - **Widget tests:**
     - The dialog's texts and the local expiry.
     - Copy writes the link to the clipboard (with a fake clipboard channel) and shows the SnackBar.
     - Share passes the right text to `onShare`.
     - Close closes the dialog.
   - **Check:** analyze is clean and all tests pass. iOS needs `pod install` or a full rebuild because of the new plugin.

4. **Invite action on the overview** (`space_overview_page.dart`)
   - The page provides a `SpaceInvitationBloc` from `get_it`.
   - The **Invite** action (`Icons.person_add_alt_1`, tooltip "Invite") shows in the normal AppBar only when the overview is loaded. It's hidden in selection mode.
   - Tapping it dispatches `SpaceInvitationRequested(spaceId)`. While the request runs, a 24px spinner replaces the action.
   - A `BlocListener` shows the dialog on success, with the overview's space name, and a SnackBar with the message on failure. The SnackBar comes after `hideCurrentSnackBar()`.
   - **Widget tests:**
     - The action shows only when the overview is loaded and not in selection mode.
     - The spinner shows while the request runs.
     - Success opens the dialog with the link.
     - Failure shows the SnackBar and enables the action again.
   - **Manual checks:**
     - Against the real backend: create an invitation, check that it expires 24 hours out in local time, copy it, and share it to WhatsApp.
     - The link arrives as plain text. That's expected until the join spec and the redirect exist.

---

## Acceptance criteria

**Data and domain**
- [ ] `SpaceRemoteDataSource.createInvitation('space-1')` sends `POST /api/v1/spaces/space-1/invitations` with no body.
- [ ] A 201 response becomes a `SpaceInvitation` with the same `id`, `token` and `spaceId`.
  - Its `expiresAt` for `"2026-09-29T21:00:00"` equals `DateTime.utc(2026, 9, 29, 21)`.
- [ ] Each error status gives the matching failure, with the backend `detail` when there is one:

  | Status | Failure | Default message |
  |---|---|---|
  | 400 | `SpaceValidationFailure` | (existing) |
  | 401 | `SpaceUnauthorizedFailure` | (existing) |
  | 403 | `SpaceForbiddenFailure` | (existing) |
  | 409 | `SpaceConflictFailure` | "You're not a participant of this space." |
  | 500 | `SpaceServerFailure` | (existing) |
  | No response | `SpaceNetworkFailure` | (existing) |

- [ ] `get_it` resolves `CreateSpaceInvitationUseCase` and `SpaceInvitationBloc`.

**Link**
- [ ] `invitationLink('abc')` returns `freshkeep://join?token=abc`.
- [ ] A token with reserved characters, such as `a b&c`, comes out URL-encoded: `freshkeep://join?token=a+b%26c`.

**Bloc**
- [ ] `SpaceInvitationRequested` emits `inProgress`, then `success` with the invitation, or `failure` with the failure's message.
- [ ] A second `SpaceInvitationRequested` sent while one is `inProgress` doesn't call the use case again.
- [ ] Two failures in a row with the same message both reach a `BlocListener`.

**Overview page**
- [ ] With the overview loaded and not in selection mode, the AppBar shows an Invite action with the tooltip "Invite".
- [ ] The Invite action doesn't show while the overview is loading, when it failed to load, or in selection mode.
- [ ] Tapping Invite replaces the action with a spinner until the request finishes.

**Dialog**
- [ ] On success, a dialog shows:
  - "Invite to {space name}".
  - The link `freshkeep://join?token=<token>`.
  - "Expires {yyyy-MM-dd HH:mm}", with `expiresAt` converted to the phone's local time.
- [ ] **Copy** puts exactly the link on the clipboard and shows the "Link copied" SnackBar.
- [ ] **Share** opens the share sheet with exactly "Join my space {space name} on Fresh Keep: {link}".
- [ ] **Close** closes the dialog, and the overview is unchanged.

**Failure**
- [ ] On failure, a SnackBar shows the failure's message, no dialog opens, and the Invite action can be tapped again.
- [ ] Tapping Invite again after closing the dialog creates a **new** invitation, with a new request to the backend.

**Checks**
- [ ] `flutter analyze` reports no issues, and `flutter test` passes.
- [ ] **Manual, against the real backend:**
  - A new invitation's expiry is about 24 hours from now in local time.
  - Share opens WhatsApp with the message and link.

---

## Decisions taken and discarded

- **Yes:** Only the custom scheme (`freshkeep://`), with no web domain.
  - **Discarded, for now:** an https redirect page on GitHub Pages. It was briefly in scope and then left for a later spec, so this one stays small. It's the fix for links that can't be tapped in WhatsApp.
- **Yes:** This spec only creates and shares the link.
  - **Discarded:** registering the scheme on Android and iOS here. Without a `/join` route, go_router would open the app on an error screen, so registration goes in the join spec along with the route and the join call.
- **Yes:** The link is `freshkeep://join?token=<token>`. The token is all the join endpoint needs, and the link stays short.
  - **Discarded:** `freshkeep://invitations/<token>`, or adding the `spaceId`. The join response already returns the `spaceId`.
- **Yes:** The link base is a constant (`kInvitationLinkBase`), which is the only thing that changes when a domain or redirect exists.
  - **Discarded:** `--dart-define`. There's no build-time variation yet.
- **Yes:** The Invite action goes in the overview's normal AppBar. The user is already inside the space there, and the overview has the space's id and name.
  - **Discarded:** a menu on the Home space cards, or both places.
- **Yes:** A dialog with the link, the expiry, and **Copy**, **Share** and **Close**. Share covers WhatsApp, and Copy covers everything else.
  - **Discarded:** only copy, or only share.
- **Yes:** `share_plus` for the share sheet. It's the standard Flutter plugin for this.
  - **Discarded:** no share at all. The user wanted the WhatsApp flow.
- **Yes:** Every tap creates a new invitation.
  - **Discarded:** caching the last one. The backend can't list invitations, and they're cheap and last 24 hours.
- **Yes:** A new `SpaceInvitationBloc` in `lib/features/spaces/`, because it's the Space API. This keeps `SpaceOverviewBloc` from taking on a third side flow.
  - **Discarded:** an `InvitationStatus` in `SpaceOverviewBloc`, as SPEC 11 did with `ProductMoveStatus`.
- **Yes:** Read `expiresAt` as UTC and show it in local time. The contract says the value comes from the server's UTC clock with no offset.
  - **Discarded:** parsing it as local time, which would shift the expiry by the phone's UTC offset.
- **Yes:** A new `SpaceConflictFailure` for 409 in `SpaceRepositoryImpl._mapDioException`.
  - **Discarded:** letting 409 fall to the `default` branch, which would show a misleading "Network error".
- **Yes:** The share call is passed to the dialog as an optional `onShare`, so widget tests can check the shared text without the plugin.
- **No:** `userCreatorId` and `isActive` in the entity. Nothing in this spec uses them.

---

## Identified risks

| Risk | Mitigation |
|---|---|
| **WhatsApp and most messaging apps don't make `freshkeep://` links tappable.** The recipient sees plain text. | Accepted for this spec. The shared message includes the full link so it can be copied. The https redirect page is the planned fix (out of scope). |
| **The link doesn't open the app yet,** because the scheme isn't registered until the join spec. | Expected and documented in the scope. Manual testing stops at "the link is created, copied and shared". |
| **Another app could register the same `freshkeep` scheme** (no domain verification). It could then receive the token and join the space. | Accepted: an invitation lasts only 24 hours. Verified https links (App Links / Universal Links) need a domain and are the long-term fix. |
| **An invitation can't be revoked.** Anyone who gets the link, even by forwarding, can join for 24 hours, with no limit on uses. | This is the backend's current design (contract §4). The dialog shows the expiry so the user knows how long the link is valid. Revoking needs a backend change and its own spec. |
| **The expiry could be off by the server's offset** if the backend ever stops serializing UTC. | The UTC reading follows the contract. A model test pins it, so a contract change is noticed. |
| **Adding `share_plus` means a native rebuild** (`pod install` on iOS). A hot restart won't pick it up. | Mentioned in Step 3's check. |
| **The share sheet can't be widget-tested** through the plugin. | `onShare` is passed in and faked in tests. The real share is checked by hand (Step 4). |
