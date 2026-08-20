# SPEC 02 — Registration response without auto-login

> **Status:** Approved
> **Depends on:** SPEC 01 (login-registration-jwt)
> **Date:** 2026-08-20
> **Objective:** Adapt the frontend registration flow to the backend's new response shape (`{ accountId, email }`, no token) by removing auto-login on registration and instead redirecting to the Login screen with a success message.

---

## Why this spec exists

The backend was refactored for SOLID/modular separation and `POST /register/user` (and `/register/admin`) no longer returns a JWT — only account metadata. The frontend currently treats registration and login as the same "authenticate" operation (`AuthResponseModel` with `jwtString`/`expiresIn` shared by both, `AuthRepositoryImpl._authenticate` persisting a session for both, `RegisterBloc` dispatching `LoggedIn` to `AuthBloc`). That coupling must be broken: registration becomes a pure "create account" action with no session side effects, and login remains the only path that establishes a session.

---

## Scope

**In:**

- New `RegisterResponseModel` (`accountId`, `email` only) in `lib/features/auth/data/models/`, with a `toUserModel()` mapping into the existing `User` entity — no new domain types needed.
- `AuthRemoteDataSource.register()` returns `RegisterResponseModel` instead of `AuthResponseModel`.
- `AuthResponseModel` (`accountId`, `email`, `jwtString`, `expiresIn`) becomes login-only — used solely by `AuthRemoteDataSource.login()`.
- `AuthRepositoryImpl.register()` split out of the shared `_authenticate()` helper: calls the datasource, maps the response straight to a `User`, and does **not** call `localDataSource.saveSession(...)` or touch secure storage at all.
- `AuthRepositoryImpl.login()` keeps using `_authenticate()` unchanged (still persists the session).
- `RegisterBloc`: remove the `authBloc.add(LoggedIn(user))` call and the now-unused `authBloc` dependency/constructor parameter entirely.
- `RegisterPage`: on `FormSuccess`, show a SnackBar with the message "Account created successfully! Please log in to continue.", then navigate to `/login` after a short delay so the user can read it.
- Update `lib/app.dart` wiring: `RegisterBloc(...)` construction drops the `authBloc: authBloc` argument.
- Update/extend `test/features/auth/data/repositories/auth_repository_impl_test.dart`: add a case asserting a successful `register()` call does **not** persist a session (no token saved to secure storage), matching the new behavior.
- `AuthRepository`, `RegisterUseCase`, and the `User` domain entity are unchanged — `Either<AuthFailure, User>` already matches the new response shape exactly.

**Out of scope (for future specs):**

- Admin registration (`POST /register/admin`) integration in the frontend — still not implemented at all in this codebase (per SPEC 01), and the backend's admin-login path is currently non-functional per `api_contract.md`. This spec only shapes the shared response-model layer that a future admin spec would reuse; no admin UI or datasource call is added here.
- Any change to the login flow, JWT decoding, route protection, or logout — untouched by this spec.
- Real-time/as-you-type validation, forgot-password, email verification — remain out of scope per SPEC 01 and not reopened here.
- Personalizing the success message with the registered email — the message stays generic per the contract's suggested copy; `FormSuccess` keeps carrying the `User` for a possible future tweak but it isn't used in the message text today.

---

## Data model

This feature introduces one new data model and narrows an existing one; it introduces no new domain entities (reuses `User` from SPEC 01).

### `lib/features/auth/data/models/register_response_model.dart` (new)

```dart
class RegisterResponseModel {
  final String accountId;
  final String email;

  const RegisterResponseModel({required this.accountId, required this.email});

  factory RegisterResponseModel.fromJson(Map<String, dynamic> json) {
    return RegisterResponseModel(
      accountId: json['accountId'] as String,
      email: json['email'] as String,
    );
  }

  UserModel toUserModel() => UserModel(id: accountId, email: email);
}
```

### `lib/features/auth/data/models/auth_response_model.dart` (unchanged shape, now login-only)

```dart
class AuthResponseModel {
  final String accountId;
  final String email;
  final String jwtString;
  final int expiresIn;
  // fromJson / toUserModel() unchanged — only its caller narrows to AuthRemoteDataSource.login()
}
```

### `lib/features/auth/data/datasources/auth_remote_datasource.dart` (signature change)

```dart
Future<RegisterResponseModel> register(AuthRequestModel request); // was Future<AuthResponseModel>
Future<AuthResponseModel> login(AuthRequestModel request);        // unchanged
```

`AuthRequestModel` (email + password) is unchanged — same shape for both endpoints.

---

## Implementation plan

1. Create `lib/features/auth/data/models/register_response_model.dart` with `RegisterResponseModel { accountId, email }`, `fromJson`, and `toUserModel()`. Manual test: `flutter analyze` passes (new file compiles standalone).
2. Update `lib/features/auth/data/datasources/auth_remote_datasource.dart`: change `register()`'s return type to `Future<RegisterResponseModel>`, parsing the response body with `RegisterResponseModel.fromJson`. `login()` stays untouched.
3. Update `lib/features/auth/data/repositories/auth_repository_impl.dart`: replace the shared `_authenticate()` call inside `register()` with a dedicated implementation that calls `remoteDataSource.register(...)`, maps the result to `Right(response.toUserModel())` on success, and reuses the existing `_mapDioException` for failures — with no call to `localDataSource.saveSession(...)`. `login()` keeps calling `_authenticate()` unchanged. Manual test: `flutter analyze` passes; existing `409 maps to ConflictFailure` test (which calls `repository.register(...)`) still passes unmodified.
4. Add a new test case to `test/features/auth/data/repositories/auth_repository_impl_test.dart`: on a successful (`201`) `register()` response, assert the returned `User` matches the response and that no token was written to secure storage (e.g. spy/assert via a fake `AuthLocalDataSource` or by asserting `getToken()` still returns `null` afterward).
5. Update `lib/features/auth/presentation/bloc/register_bloc.dart`: remove the `authBloc` field/constructor parameter and the `authBloc.add(LoggedIn(user))` call; `_onSubmitted` now just emits `FormFailure`/`FormSuccess(user)` based on the use case result.
6. Update `lib/app.dart`: drop the `authBloc: authBloc` argument from the `RegisterBloc(...)` construction.
7. Update `lib/features/auth/presentation/pages/register_page.dart`: in the `BlocListener`'s `FormSuccess` branch, show a SnackBar with "Account created successfully! Please log in to continue.", then `Future.delayed(const Duration(seconds: 2), () => context.go('/login'))`, guarded by a `mounted` check. Manual test: `flutter run`, register a new account against the backend, confirm the SnackBar appears and the app lands on `/login` ~2s later, still unauthenticated (`AuthBloc` stays `Unauthenticated`).
8. Run `flutter analyze` and `flutter test` for the full suite to confirm nothing else references the old `AuthResponseModel`-based register path.

---

## Acceptance criteria

- [ ] `RegisterResponseModel` parses a `{ accountId, email }` JSON body without attempting to read `jwtString` or `expiresIn`.
- [ ] `AuthRemoteDataSource.register()` returns a `RegisterResponseModel`; `AuthRemoteDataSource.login()` still returns an `AuthResponseModel` with `jwtString`/`expiresIn`, unchanged.
- [ ] A successful `AuthRepositoryImpl.register()` call does not write anything to secure storage — `AuthLocalDataSource.getToken()` returns `null` both before and after registration.
- [ ] A successful `AuthRepositoryImpl.login()` call still persists the session as before (unchanged behavior).
- [ ] `RegisterBloc` no longer has an `authBloc` dependency, and no longer dispatches `LoggedIn` on successful registration.
- [ ] `AuthBloc`'s state remains `Unauthenticated` immediately after a successful registration (never transitions to `Authenticated`).
- [ ] On successful registration, a SnackBar reading "Account created successfully! Please log in to continue." is shown on the Register screen.
- [ ] After the SnackBar's delay elapses, the app navigates to `/login`.
- [ ] Registration error handling (400 validation, 409 conflict) is unchanged — same messages, same inline/SnackBar display as SPEC 01.
- [ ] `flutter analyze` passes with no references to `jwtString`/`expiresIn` remaining on the register path.
- [ ] `flutter test` passes, including the new "register does not persist a session" test case.

---

## Decisions

- **Yes:** Separate `RegisterResponseModel` (`accountId`, `email` only), distinct from `AuthResponseModel`. Matches the contract exactly, no nullable token fields, no ambiguity about whether a register response could ever carry a token.
- **No:** Reusing `AuthResponseModel` with nullable `jwtString`/`expiresIn`. Would leak login-only concerns into the register path and risks a future accidental null-token read.
- **Yes:** Split `AuthRepositoryImpl.register()` into its own implementation instead of threading a `persistSession` boolean through the shared `_authenticate()` helper. Keeps register structurally incapable of persisting a session, rather than relying on a flag being passed correctly at every call site.
- **No:** A `persistSession: bool` flag on `_authenticate()`. Rejected as an easy-to-misuse shared-logic footgun.
- **Yes:** Success UX is SnackBar-on-register-page-then-delayed-navigate (`Future.delayed` + `context.go('/login')`), not an immediate navigate with the message surfaced on the Login page. No router/login-page changes needed, message is guaranteed visible before the screen changes.
- **No:** Passing the message through `GoRouter`'s `extra` param to show it on the Login page. More moving parts (router wiring, login page changes) for a marginal UX gain.
- **Yes:** `FormSuccess` keeps carrying the registered `User`. No behavior depends on it today (message is generic, per the contract's suggested copy), but it costs nothing to keep and avoids a churny state-shape change if a future spec wants to personalize the message.
- **No:** Changing `FormSuccess` to carry no payload. Would be a gratuitous breaking change to `FormStatus` for no current benefit.
- **Yes:** Remove the `authBloc` dependency from `RegisterBloc` entirely (not just the `.add(LoggedIn(...))` call), since nothing else in the bloc needs it once auto-login is gone. Also updates `lib/app.dart`'s `RegisterBloc(...)` construction accordingly.
- **Yes:** `AuthRepository`, `RegisterUseCase`, and the `User` domain entity are left unchanged. `Either<AuthFailure, User>` and `{ id, email }` already match the new response shape — no domain-layer churn needed for this change.
- **Yes:** Admin registration (`register/admin`) stays out of scope. It isn't implemented in the frontend at all yet (per SPEC 01), and the backend's admin-login path is currently non-functional per `api_contract.md`'s "Known limitation" — no reason to build toward it now.

---

## Risks

| Risk | Mitigation |
| --- | --- |
| `Future.delayed(...)` navigating after the `RegisterPage` widget has been disposed (e.g. user backs out manually before the delay elapses) throws or navigates on a dead context | Guard the delayed callback with a `mounted` check before calling `context.go('/login')`. |
| Missed reference to the old shared `AuthResponseModel`-based register path elsewhere in the codebase (e.g. a widget test or mock) causes a silent compile/runtime break | Step 8 in the implementation plan runs `flutter analyze` + full `flutter test` specifically to catch this before considering the spec done. |

---

## What is **not** in this spec

- Admin registration (`register/admin`) frontend integration — its own spec once there's an admin-facing UI to build it from.
- Any change to the login flow, JWT decoding, route protection, or logout.
- Real-time (as-you-type) field validation, forgot-password, email verification.
- Personalizing the success message with the registered email.

Each one of those, if it lands, goes in its own spec.
