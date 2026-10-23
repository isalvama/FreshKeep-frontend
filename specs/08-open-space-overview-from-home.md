# SPEC 08 — Tapping a space on Home opens its overview

> **Status:** Approved
> **Depends on:** SPEC 04 (fetch-and-display-spaces-on-login) — extends the Home spaces list and `SpacesBloc`; SPEC 06 (confirm-reprocess-and-space-overview) — reuses the `/space-overview/:spaceId` route, `SpaceOverviewBloc` and `SpaceOverviewPage`, and adds a way back to Home from that page. No new backend endpoints: reuses `GET /api/v1/spaces/{spaceId}/overview` and the existing get-user-spaces call.
> **Date:** 2026-09-29
> **Objective:** Make each space on Home tappable so it opens that space's overview, with a way back to Home from every overview state and a silent refresh of the spaces list on return.

---

## Scope

**In:**

- **Home — tappable space tiles:** each space's `ListTile` in `home_page.dart` gets an `onTap` and a trailing `Icons.chevron_right`. Tapping does `context.push('/space-overview/<space.id>', extra: space)` (the whole `Space` entity), so the overview opens on top of Home and Home keeps its state underneath.
- **Home — silent refresh on return:** when the `push` future completes (the user came back from the overview), Home dispatches a new `SpacesRefreshed` event on `SpacesBloc`. Unlike `SpacesRequested`, it never emits `loading`: the current list stays on screen and is replaced only on success; on failure the current list and state are kept, with no message.
- **Overview — AppBar in every state:** `SpaceOverviewPage`'s loading, load-failure and loaded screens all get an `AppBar`.
- **Overview — AppBar title:**
  - Loading / load failure: `"<emoji> <spaceName>"` from `extra` when a `Space` was passed; otherwise `"Space"` (receipt flow, deep link, `extra` lost).
  - Loaded: always the overview response's `emoji` + `name`, even if `extra` was present.
- **Overview — leading button:** when the page can pop (opened from Home), the default back arrow pops back to Home. When it can't pop (reached from the receipt flow via `context.go`), the leading button navigates with `context.go('/home')`.
- **Router:** the `/space-overview/:spaceId` route reads `state.extra as Space?` and passes it to `SpaceOverviewPage`. Fetching still depends on `spaceId` only.

**Out of scope (for future specs):**

- Refreshing Home's spaces in any other situation (returning from the receipt flow via `context.go('/home')`, app resume, pull-to-refresh).
- A visible message when the silent refresh fails.
- Restyling the Home list as Material `Card`s or any other visual change beyond the chevron.
- Changing how the receipt flow reaches the overview — it keeps using `context.go`; it only gains the leading "go to Home" button described above.
- Editing or deleting spaces, storage spots or products from the overview — it stays view-only, as in SPEC 06.
- Any change to `SpaceOverviewBloc`, its data layer or the overview endpoint.

---

## Data model

No new entities, models or API shapes. Only one bloc event and one page parameter.

### `spaces` — new bloc event

```dart
// presentation/bloc/spaces_event.dart
final class SpacesRefreshed extends SpacesEvent {
  const SpacesRefreshed();
}
```

`SpacesBloc` handles it in a new `_onSpacesRefreshed`: calls `getUserSpacesUseCase()` **without** emitting `SpacesStatus.loading`.

- `Right(spaces)` → `state.copyWith(spaces: spaces, status: SpacesStatus.loaded, errorMessage: null)`.
- `Left(failure)` → emits nothing (list, status and `errorMessage` stay as they were).

`SpacesState` is unchanged.

### `space_overview` — page parameter

```dart
// presentation/pages/space_overview_page.dart
class SpaceOverviewPage extends StatelessWidget {
  const SpaceOverviewPage({super.key, required this.spaceId, this.space});

  final String spaceId;
  final Space? space; // from GoRouter `extra` when opened from Home; null otherwise
}
```

`space` is used only for the AppBar title while loading or on load failure. It is never passed to `SpaceOverviewBloc` or used for fetching.

### Router

```dart
// routes/app_router.dart — /space-overview/:spaceId
final space = state.extra as Space?;
// ... SpaceOverviewPage(spaceId: spaceId, space: space)
```

---

## Implementation plan

1. **`SpacesRefreshed` event.** Add `SpacesRefreshed` to `spaces_event.dart` and register `_onSpacesRefreshed` in `SpacesBloc` (no `loading`; replaces the list on success; emits nothing on failure). Nothing dispatches it yet. Manual test: bloc tests — from a `loaded` state, a successful refresh emits only the new `loaded` state (no `loading`); a failed refresh emits nothing; `SpacesRequested` behaves as before.
2. **Overview AppBar, title and leading button.** In `app_router.dart`, read `state.extra as Space?` and pass it to `SpaceOverviewPage(spaceId:, space:)`. In `SpaceOverviewPage`, add the optional `space` parameter and give the loading, load-failure and loaded states an `AppBar`. Title while loading/on failure: `"<emoji> <spaceName>"` from `space`, otherwise `"Space"`; once loaded, always the overview response. When `!context.canPop()`, the leading button is an `IconButton` (`Icons.arrow_back`, tooltip `'Back to Home'`) that calls `context.go('/home')`; otherwise the default back arrow is used. The receipt flow now has a way back to Home. Manual test: overview widget tests — all three states render an `AppBar`; loading shows the `extra` title, or `"Space"` without it; loaded shows the response's title even when `extra` differs; with nothing to pop, the leading button goes to `/home`; with something to pop, back pops.
3. **Home — tappable tiles and refresh on return.** In `home_page.dart`, each space tile gets a trailing `Icons.chevron_right` and an `onTap` that awaits `context.push('/space-overview/${space.id}', extra: space)`, then — if `context.mounted` — dispatches `SpacesRefreshed`. Manual test: Home widget tests — every tile shows the chevron; tapping a tile pushes `/space-overview/<id>` with that `Space` as `extra`; popping back dispatches `SpacesRefreshed` (the list updates from a stubbed use case and no spinner appears).
4. **Full verification.** Run `flutter analyze` and the full `flutter test` suite; both must be clean.

After Step 2 the overview is independently better (including from the receipt flow); after Step 3 the feature is complete.

---

## Acceptance criteria

**Home**

- [ ] Every space tile on Home shows a trailing `Icons.chevron_right`.
- [ ] Tapping a space tile opens `/space-overview/<space.id>` on top of Home (`push`), with that `Space` passed as `extra`.
- [ ] Returning from the overview dispatches `SpacesRefreshed` exactly once.
- [ ] A successful `SpacesRefreshed` replaces the displayed list without ever showing a spinner.
- [ ] A failed `SpacesRefreshed` leaves the displayed list unchanged, with no error screen and no message.
- [ ] `SpacesRequested` behaves exactly as before (`loading` state, Retry on failure).

**Overview**

- [ ] The loading, load-failure and loaded states each render an `AppBar`.
- [ ] Opened from Home, the loading/load-failure title is `"<emoji> <spaceName>"` of the tapped space.
- [ ] Opened without `extra` (receipt flow, deep link), the loading/load-failure title is `"Space"`.
- [ ] Once loaded, the title is always the overview response's `"<emoji> <name>"`, even if it differs from `extra`.
- [ ] Opened from Home, the back arrow returns to Home with the list still in place.
- [ ] Reached from the receipt flow (nothing to pop), the leading button (tooltip `'Back to Home'`) navigates to `/home`.
- [ ] The overview still fetches by `spaceId` only; `SpaceOverviewBloc` and its data layer are unchanged.

**Quality**

- [ ] `flutter analyze` reports no issues.
- [ ] `flutter test` passes in full, including the new bloc, overview and Home tests.

---

## Decisions taken and discarded

| Decision | Chosen | Discarded | Why |
|---|---|---|---|
| Navigation from Home | `context.push` (overview on top of Home) | `context.go` (replaces Home) | Going back to the list is the natural next step; `push` gives a back arrow and keeps Home's state. |
| Look of the space tile | Keep `ListTile`; add `onTap` + trailing chevron | Restyle as Material `Card`; `onTap` only, no visual cue | The chevron is the smallest change that makes the tile look tappable; restyling is a separate visual decision. |
| What goes in `extra` | The whole `Space` entity | A dedicated title class | Simpler; the entity already exists and the page only reads `emoji` and `spaceName`. |
| Title before the overview loads | `extra`'s emoji + name, else `"Space"` | Empty title; always `"Space"` | From Home the name shows immediately; the fallback covers the receipt flow, deep links and a lost `extra` (GoRouter doesn't keep `extra` across restarts). |
| Title after the overview loads | Always the overview response | Keep `extra` when present | The response is live data and fixes a name that changed after Home loaded its list. |
| AppBar on loading/error states | All three states | Only the loaded state | Otherwise a user stuck on the spinner or an error has no way out. |
| Leaving an overview reached from the receipt flow | When `!canPop()`, the leading button does `context.go('/home')` | Defer to another spec | Same fix as the AppBar change and nearly free; before this spec that screen was a dead end. |
| Home refresh on return | New `SpacesRefreshed` event: silent, no `loading`, replaced only on success | Reuse `SpacesRequested` | Reusing it would flash a spinner and, on failure, replace a list that was valid seconds ago with the error screen. |
| Failed silent refresh | Keep the list, no message | SnackBar | The list on screen was just valid; a real load failure still has its own Retry path. |
| When Home refreshes | Only when returning from the overview | Also after the receipt flow's `go('/home')`, app resume, pull-to-refresh | Spaces are shared and may change through another participant; this covers the new entry point without widening the scope. |

---

## Identified risks

| Risk | Impact | Mitigation |
|---|---|---|
| GoRouter loses `extra` (web page reload, deep link, hot restart). | Title falls back to `"Space"` until the overview loads. | Handled by design: the page never depends on `extra` for fetching, only for the early title. |
| The `push` future doesn't complete, or completes after Home is gone (web browser back, logout while on the overview). | Refresh is missed, or `context.read` runs on an unmounted widget. | Check `context.mounted` after the `await`; a missed refresh just leaves the list as it was, which is harmless. |
| `SpacesRefreshed` overlaps `SpacesRequested` or `SpaceCreated` (bloc handles events concurrently by default). | A slower refresh response could overwrite a newer list. | Unlikely: spaces can't be created from the overview and a refresh only starts on return to Home. If it shows up, move the spaces events to a `droppable`/`sequential` transformer in a later spec. |
| `canPop()` gives an unexpected result when the overview is the first page in the stack (e.g. a web deep link). | Back arrow shown where "Back to Home" was expected, or vice versa. | The leading button is chosen from `canPop()` at build time; both paths end on Home or the previous page, so the user is never stuck. Widget tests cover both. |
