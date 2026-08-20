# SPEC 01 — Login and registration with JWT session

> **Status:** Approved
> **Depends on:** None (first spec in this repo)
> **Date:** 2026-07-26
> **Objective:** Implement email/password registration and login screens, backed by the `api/v1/auth` endpoints, that persist the JWT securely, protect routes behind it, and support logout.

---

## Scope

**In:**

- Registration screen: email, password, and a client-side-only "confirm password" field. Calls `POST /api/v1/auth/register/user`.
- Login screen: email and password fields. Calls `POST /api/v1/auth/login`.
- On-submit validation (not real-time): required fields, email format, password length 8–20, confirm-password match.
- Successful registration: SnackBar confirmation, JWT stored, navigate to Home.
- Successful login: JWT stored, navigate to Home.
- Registration error handling: 400 (validation) and 409 (email already registered), each with a specific user-facing message.
- Login error handling: 400 (validation), 401 (invalid credentials — generic message), 403 (disabled account), 500 (server error), each with a specific message.
- Minimal placeholder Home screen: shows the logged-in email and a Logout button, reachable only when authenticated.
- Secure JWT persistence via `flutter_secure_storage`.
- `dio` HTTP client with an interceptor that attaches `Authorization: Bearer <token>` to every request once a token is stored.
- Route protection via `GoRouter` redirect: checks token presence and expiry (decoded locally via `jwt_decoder`'s `exp` claim) before allowing access to protected routes; redirects to Login otherwise.
- Logout: deletes the token from secure storage and redirects to Login. No backend call (stateless JWT API, nothing server-side to invalidate).
- `flutter_bloc` for auth state (registration flow, login flow, session/auth-guard state).
- Clean Architecture layering (domain/data/presentation) under a feature-first folder structure (`lib/features/auth/`).
- Domain naming: `User`.

**Out of scope (for future specs):**

- Admin registration (`POST /api/v1/auth/register/admin`) — requires an already-authenticated ADMIN caller, needs its own admin-side spec.
- The real Home page / food-records features — this spec only builds an authenticated placeholder.
- Real-time (as-you-type) field validation.
- 422 (unprocessable email domain) handling — the backend contract defines no such response.
- Forgot-password / password-reset flow.
- Email verification flow.
- "Remember me" option, social login, biometric login.
- Refresh-token flow — the contract has no refresh endpoint; when the token expires the user is simply redirected to Login.
- Multi-device / multi-session management.

---

## Data model

### Domain layer (`lib/features/auth/domain/`)

```dart
// entities/user.dart
class User {
  final String id;    // maps from backend's accountId
  final String email;
}

// repositories/auth_repository.dart — interface, implemented in data/
abstract class AuthRepository {
  Future<Either<AuthFailure, User>> register(String email, String password);
  Future<Either<AuthFailure, User>> login(String email, String password);
  Future<void> logout();
  Future<bool> hasValidSession();   // token exists AND jwt_decoder says not expired
  Future<User?> currentUser();     // last known session user, cached in memory
}

// usecases/ — one class per action, each wraps a single AuthRepository call
class RegisterUseCase { Future<Either<AuthFailure, User>> call(String email, String password); }
class LoginUseCase { Future<Either<AuthFailure, User>> call(String email, String password); }
class LogoutUseCase { Future<void> call(); }
class CheckAuthStatusUseCase { Future<bool> call(); }
```

### Shared failures (`lib/core/errors/failures.dart`)

```dart
sealed class AuthFailure { final String message; }
class ValidationFailure extends AuthFailure { }         // 400
class ConflictFailure extends AuthFailure { }            // 409 — register only
class InvalidCredentialsFailure extends AuthFailure { }   // 401 — login only, generic message
class AccountDisabledFailure extends AuthFailure { }      // 403 — login only
class ServerFailure extends AuthFailure { }               // 500
class NetworkFailure extends AuthFailure { }              // no connectivity / timeout
```

### Data layer (`lib/features/auth/data/`)

```dart
// models/user_model.dart
class UserModel extends User {
  // fromJson(Map<String,dynamic> json) reads json['accountId'] into id, json['email'] into email
}

// models/auth_request_model.dart / auth_response_model.dart — same shape as before,
// AuthResponseModel.toUserModel() extracts { accountId, email } into a UserModel

// datasources/auth_remote_datasource.dart
class AuthRemoteDataSource {
  Future<AuthResponseModel> register(AuthRequestModel request); // via dio, throws DioException on non-2xx
  Future<AuthResponseModel> login(AuthRequestModel request);
}

// datasources/auth_local_datasource.dart
class AuthLocalDataSource {
  Future<void> saveToken(String jwt);
  Future<String?> getToken();
  Future<void> deleteToken();
}

// repositories/auth_repository_impl.dart
// Implements AuthRepository: calls remote datasource, catches DioException,
// maps HTTP status -> AuthFailure subtype (400->ValidationFailure, 409->ConflictFailure,
// 401->InvalidCredentialsFailure, 403->AccountDisabledFailure, 500->ServerFailure,
// no response->NetworkFailure), and on success persists the token via local datasource.
```

### Secure storage key

```
key: "auth_jwt_token"
value: "<jwtString>"
```

### Presentation layer (`lib/features/auth/presentation/bloc/`)

```dart
// auth_bloc.dart — app-wide session state, drives GoRouter redirect
sealed class AuthState { }
class AuthInitial extends AuthState { }          // checking secure storage on app start
class Authenticated extends AuthState { final User user; }
class Unauthenticated extends AuthState { }

sealed class AuthEvent { }
class AppStarted extends AuthEvent { }
class LoggedIn extends AuthEvent { final User user; }
class LoggedOut extends AuthEvent { }

// login_bloc.dart / register_bloc.dart — per-form submission state
sealed class FormStatus { }
class FormInitial extends FormStatus { }
class FormSubmitting extends FormStatus { }
class FormSuccess extends FormStatus { final User user; }
class FormFailure extends FormStatus { final String message; } // AuthFailure.message, form-ready copy
```

---

## Implementation plan

1. Add dependencies to `pubspec.yaml`: `dio`, `flutter_bloc`, `go_router`, `flutter_secure_storage`, `jwt_decoder`, `fpdart`, `equatable`. Run `flutter pub get`. Manual test: `flutter run` still shows the unchanged starter screen.
2. Create `lib/core/errors/failures.dart` with the `AuthFailure` sealed hierarchy (`ValidationFailure`, `ConflictFailure`, `InvalidCredentialsFailure`, `AccountDisabledFailure`, `ServerFailure`, `NetworkFailure`).
3. Create the domain layer: `features/auth/domain/entities/user.dart` and `features/auth/domain/repositories/auth_repository.dart` (interface only, no implementation yet).
4. Create the use cases in `features/auth/domain/usecases/`: `RegisterUseCase`, `LoginUseCase`, `LogoutUseCase`, `CheckAuthStatusUseCase` — each depends only on the `AuthRepository` interface. Manual test: `flutter analyze` passes with no implementation existing yet (interface-only compiles fine).
5. Create data models in `features/auth/data/models/`: `AuthRequestModel`, `AuthResponseModel`, `UserModel`, with `fromJson`/`toJson`.
6. Create `lib/core/network/dio_client.dart`: a configured `Dio` instance (base URL, `application/json` headers) with an interceptor that reads the stored JWT and attaches `Authorization: Bearer <token>` when present.
7. Create `features/auth/data/datasources/auth_remote_datasource.dart` using the shared `Dio` client: `register()` and `login()` calls against `POST /api/v1/auth/register/user` and `POST /api/v1/auth/login`.
8. Create `features/auth/data/datasources/auth_local_datasource.dart` wrapping `flutter_secure_storage`: `saveToken`, `getToken`, `deleteToken` under the `auth_jwt_token` key.
9. Implement `features/auth/data/repositories/auth_repository_impl.dart`: wires both datasources, maps `DioException` HTTP status codes to `AuthFailure` subtypes, decodes the JWT via `jwt_decoder` for `hasValidSession()`/`currentUser()`. Manual test: unit test the status-code-to-failure mapping with a mocked `Dio`.
10. Create `features/auth/presentation/bloc/auth_bloc.dart` (session state: `AuthInitial`/`Authenticated`/`Unauthenticated`), using `CheckAuthStatusUseCase` and `LogoutUseCase`.
11. Build the Login screen: `login_bloc.dart` + `presentation/pages/login_page.dart` (email/password fields, on-submit validation, calls `LoginUseCase`, shows `FormFailure.message` inline, on success dispatches `LoggedIn` to `AuthBloc`). Manual test: `flutter run`, attempt login against a running backend, see success/failure paths.
12. Build the Register screen: `register_bloc.dart` + `presentation/pages/register_page.dart` (email/password/confirm-password, validation, calls `RegisterUseCase`, SnackBar confirmation on success, dispatches `LoggedIn`). Manual test: register a new account against the backend, confirm 409 shows "User already exists" on retry.
13. Build the minimal Home screen: `presentation/pages/home_page.dart` showing `user.email` and a Logout button dispatching `LogoutUseCase` then `LoggedOut`.
14. Configure `lib/routes/app_router.dart` with `GoRouter`: routes `/login`, `/register`, `/home`; `redirect` logic reads `AuthBloc` state — unauthenticated users are redirected to `/login`, authenticated users hitting `/login`/`/register` are redirected to `/home`.
15. Wire `lib/main.dart`/`lib/app.dart`: bootstrap `AuthBloc` (dispatch `AppStarted` on startup), replace the counter starter with `MaterialApp.router` using the configured `GoRouter`. Manual test: cold-start the app with no stored token → lands on Login; log in → lands on Home; kill and relaunch the app → still lands on Home (valid token persisted); log out → back on Login.

---

## Acceptance criteria

### Registration

- [ ] The Register screen has fields for email, password, and confirm-password.
- [ ] Submitting with an empty required field shows an inline validation error and does not call the API.
- [ ] Submitting with an invalid email format shows an inline validation error and does not call the API.
- [ ] Submitting with a password shorter than 8 or longer than 20 characters shows an inline validation error and does not call the API.
- [ ] Submitting with a confirm-password that doesn't match the password shows an inline validation error and does not call the API.
- [ ] On `201 Created`, a SnackBar confirmation appears, the JWT is stored in `flutter_secure_storage`, and the app navigates to Home.
- [ ] On `400 Bad Request` from the backend, a message describing the validation problem is shown.
- [ ] On `409 Conflict`, the message "User already exists" (or equivalent) is shown.

### Login

- [ ] The Login screen has fields for email and password.
- [ ] Submitting with an empty required field shows an inline validation error and does not call the API.
- [ ] On `200 OK`, the JWT is stored in `flutter_secure_storage` and the app navigates to Home.
- [ ] On `401 Unauthorized`, the generic message "Invalid email or password" is shown (never indicating which field was wrong).
- [ ] On `403 Forbidden`, a message indicating the account is disabled is shown.
- [ ] On `500 Internal Server Error`, a generic "something went wrong" message is shown.

### Session, routing, and logout

- [ ] Every outgoing request made after a token exists in secure storage includes an `Authorization: Bearer <token>` header, added automatically by the Dio interceptor.
- [ ] On app start, if no token is stored, the app opens on the Login screen.
- [ ] On app start, if a stored token's JWT `exp` claim is in the past, the app opens on the Login screen (and the stale token is cleared).
- [ ] On app start, if a stored token's JWT `exp` claim is still valid, the app opens on the Home screen without requiring re-login.
- [ ] Attempting to navigate directly to `/home` while unauthenticated redirects to `/login`.
- [ ] Pressing Logout on Home deletes the stored token and navigates to Login, with no backend call made.
- [ ] The Home screen displays the logged-in user's email.

---

## Decisions

- **Yes:** Email-only authentication, no username field. Matches `AuthRequest` in the contract exactly (email + password only).
- **No:** Keeping a username field. The backend has no such field; it would be dead UI.
- **Yes:** Drop 422 handling entirely. The contract defines no such response for these endpoints.
- **No:** A named defensive case for 422. Any unrecognized status falls into the generic error path instead.
- **Yes:** Logout is client-side only — delete the token, redirect to Login, no backend call. The API is stateless JWT with no server-side session, and no logout endpoint exists in the contract.
- **Yes:** Explicit handling for 403 (disabled account) and 500 (server error) on login, in addition to 401. All three are real cases defined in the contract's `GlobalExceptionHandler` mapping.
- **Yes:** `register/admin` is out of scope. It requires an already-authenticated ADMIN caller — a chicken-and-egg problem for a "new user" flow — and belongs in its own admin-facing spec.
- **Yes:** `flutter_bloc` for state management. Explicit choice over Riverpod for a more structured, explicit event/state flow.
- **No:** Riverpod. It was the flutter-expert skill's lighter-weight suggestion, but discarded in favor of Bloc.
- **Yes:** `GoRouter` for navigation. Built-in `redirect` support is a direct fit for "redirect to Login when the token is missing/expired."
- **No:** Navigator 1.0. Would require hand-rolled guard logic on every route push.
- **Yes:** `dio` for the HTTP client. Its native `Interceptor` class is a direct fit for auto-attaching the Bearer token.
- **No:** the `http` package. Would need a manual wrapper class to fake interceptor behavior.
- **Yes:** Decode the JWT's `exp` claim locally via `jwt_decoder` for expiry checks. The contract explicitly documents `expiresIn` as the raw config value, not a countdown, so it can't be compared to "now" directly — the token's own `exp` claim is the authoritative source.
- **No:** Computing expiry as `receivedAt + expiresIn`. Discarded — it duplicates what's already encoded in the token and adds a second timestamp to keep in sync.
- **Yes:** A confirm-password field on Register, client-side only (never sent to the backend). Common UX safeguard against typos even though the API doesn't require it.
- **Yes:** Build a minimal placeholder Home screen in this spec (email + Logout button only). Without a real screen the login/register flow can't be verified end-to-end in a running app.
- **No:** Routing to a bare TODO stub instead. Would leave the core flow untestable.
- **Yes:** On-submit validation only, not real-time. Simpler first implementation; revisit in a future UX-focused spec if needed.
- **Yes:** Feature-first folder structure (`lib/features/auth/...`), matching the flutter-expert skill's reference structure and scaling better as more features are added.
- **No:** Layer-first structure. Gets unwieldy once more features exist across the whole app.
- **Yes:** Domain entity named `User`, superseding an earlier `Account` naming choice made mid-spec, per explicit correction after reviewing the first data-model draft.
- **Yes:** Clean Architecture layering (domain/data/presentation, repository interfaces in domain, implementations in data), per explicit direction — to be formalized as the project-wide convention in `CLAUDE.md`.
- **Yes:** `Either<Failure, T>` (fpdart) for repository/use-case error propagation. Keeps failure handling explicit and typed at every call site instead of relying on thrown exceptions crossing the domain boundary.
- **No:** Typed exceptions + try/catch. Discarded in favor of the more explicit functional-error style for this Clean Architecture setup.

---

## Risks

| Risk | Mitigation |
| --- | --- |
| JWT `exp` check relies on the device's local clock; clock skew could make a valid token look expired (or vice versa) | Acceptable as a soft guard only — the backend is still the source of truth and will reject an actually-expired token with 401 on the next real request. |
| `flutter_secure_storage` behavior varies by platform (Keychain/Keystore-backed on iOS/Android; different guarantees on web/desktop) | Verify manually on Android and iOS during implementation (the two platforms this spec is tested against); note any web/desktop gap as a follow-up if this app targets those. |
| `AuthBloc`'s initial check (`AuthInitial` while reading secure storage) is async — if `GoRouter`'s `redirect` doesn't account for this, it could redirect before the check resolves | `redirect` explicitly holds on a loading state while `AuthInitial`, and only redirects once the bloc resolves to `Authenticated` or `Unauthenticated`. |
| The backend base URL for the Dio client isn't decided in this spec (dev vs. prod) | Out of scope here — flagged so it isn't silently hardcoded; needs a config/env decision (e.g. `--dart-define`) before or during implementation. |

---

## What is **not** in this spec

- Admin registration (`register/admin`) — its own spec once there's an admin-facing surface to call it from.
- The real Home page / food-records features — only a minimal authenticated placeholder is built here.
- Real-time (as-you-type) field validation.
- 422 handling — not returned by the backend per the contract.
- Forgot-password / password-reset flow.
- Email verification flow.
- "Remember me", social login, biometric login.
- Refresh-token flow.
- Multi-device / multi-session management.

Each one of those, if it lands, goes in its own spec.
