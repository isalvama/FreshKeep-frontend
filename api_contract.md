# Auth API Contract

Source: `AuthController` (`modules/account/infrastructure/web`), `AppSecurityConfiguration`,
`SpringSecurityConfiguration`, `GlobalExceptionHandler`, `JwtAuthenticationFilter`,
`JwtTokenGeneratorAdapter`, `IdentityResolverService`.

Base path: `api/v1/auth`

All three endpoints consume/produce `application/json`.

---

## ⚠️ Breaking changes for existing frontend integrations

1. **`register/user` and `register/admin` no longer return a JWT.** They now return `{ accountId, email }` only — no `jwtString`, no `expiresIn`. If the current frontend auto-logs-in a user right after registration using the token from the register response, that will break: **the client must now call `POST /api/v1/auth/login` as a separate step right after a successful registration** to obtain a session token.
2. **Login's JWT now carries two extra claims**: `userId` and `adminId` (see [JWT claims](#jwt-claims)). If the frontend decodes the token client-side, these are now available — `userId`/`adminId` are `null` in the claim when the account doesn't have the corresponding role.
3. **Admin login is currently non-functional.** Any account with the `ADMIN` role will always fail `POST /login` with a `500` (see [Known limitation](#known-limitation-admin-login-always-fails)). This includes the account created via `register/admin`. Do not build/test an admin-facing flow against this yet.

---

## 1. Register — User

`POST /api/v1/auth/register/user`

### Request body (`AuthRequest`)

```json
{
  "email": "user@example.com",
  "password": "P@ssw0rd1"
}
```

| Field    | Type   | Constraints                              |
|----------|--------|-------------------------------------------|
| email    | string | required (`@NotBlank`), must be a valid email (`@Email`) |
| password | string | required (`@NotBlank`), length 8–20 (`@Size`) |

### Success response — `201 Created`

`Location` header: `/api/v1/users/{accountId}`

```json
{
  "accountId": "b3f1c9a0-....",
  "email": "user@example.com"
}
```

No token is returned. Call `POST /api/v1/auth/login` afterward to obtain one.

### Error responses

| Status | Condition | Body (`ProblemDetail`) title |
|--------|-----------|-------------------------------|
| 400 Bad Request | `email`/`password` fail bean validation | "Validation Error In Body Data" (+ `errors` map field→message) |
| 400 Bad Request | Malformed/missing JSON body | "Message Not Readable" |
| 409 Conflict | Email already registered (`AccountAlreadyExistsException`) | "Conflict Error" |

---

## 2. Register — Admin

`POST /api/v1/auth/register/admin`

Same request/response/error shapes as **Register — User**, with two differences:

- `Location` header points to `/api/v1/admins/{accountId}`.
- The created account is granted the `ADMIN` role instead of `USER`.

Same as above: the response contains only `{ accountId, email }`, no token. Note the [known limitation](#known-limitation-admin-login-always-fails) — the admin account this creates cannot currently log in.

### Access control

Enforced via `@PreAuthorize("hasRole('ADMIN')")` on `AuthController.registerAdmin`. A caller must already be authenticated **as an ADMIN** (valid `Bearer` JWT with the `ADMIN` role) to reach this endpoint.

Additional error cases — see [Security & access control](#security--access-control) for details:

| Status | Condition |
|--------|-----------|
| 401 Unauthorized | No `Authorization` header, or an invalid/malformed/expired bearer token |
| 403 Forbidden | Valid token, but the account does not have the `ADMIN` role |

---

## 3. Login

`POST /api/v1/auth/login`

### Request body (`AuthRequest`)

Same shape/constraints as registration:

```json
{
  "email": "user@example.com",
  "password": "P@ssw0rd1"
}
```

### Success response — `200 OK`

```json
{
  "accountId": "b3f1c9a0-....",
  "email": "user@example.com",
  "jwtString": "eyJhbGciOi...",
  "expiresIn": 3600000
}
```

`expiresIn` is the raw `jwt.expiration` value (milliseconds) used to build the token, not a computed remaining time.

Login also updates the account's `lastLogIn` timestamp as a side effect (`accountRepositoryPort.updateLastLogIn`).

### JWT claims

Decoding `jwtString` (e.g. for client-side identity checks) now yields:

| Claim | Type | Notes |
|-------|------|-------|
| `sub` | string | account email |
| `roles` | string[] | e.g. `["USER"]`, without the `ROLE_` prefix |
| `accountId` | string (UUID) | the authenticating `Account`'s id |
| `userId` | string (UUID) or `null` | present only if the account has the `USER` role; resolved from the `user` module at login time |
| `adminId` | string (UUID) or `null` | present only if the account has the `ADMIN` role — see limitation below |
| `iat` / `exp` | number | issued-at / expiration (epoch ms) |

### Error responses

| Status | Condition | Body title |
|--------|-----------|------------|
| 400 Bad Request | `email`/`password` fail bean validation | "Validation Error In Body Data" |
| 400 Bad Request | Malformed/missing JSON body | "Message Not Readable" |
| 401 Unauthorized | Wrong email or password (`InvalidCredentialsException`, thrown by `AuthenticationAdapter` for any `AuthenticationException`, e.g. `BadCredentialsException`/unknown user) | "Unauthorized Error" |
| 403 Forbidden | Account exists but is disabled (`DisabledAccountException`, from Spring Security's `DisabledException`) | "Forbidden Request" |
| 500 Internal Server Error | Authentication succeeded but the principal couldn't be mapped (`IdentityMappingException`) | "Server Error" |
| 500 Internal Server Error | Account has the `USER` role but no matching `User` record exists yet (`UserProvisioningPendingException`) — should not happen under normal operation | "Server Error" |
| 500 Internal Server Error | Account has the `ADMIN` role (`AdminProvisioningPendingException`) — **always thrown today**, see below | "Server Error" |
| 500 Internal Server Error | Both `userId` and `adminId` resolved to nothing (`InvalidResolvedEntitiesException`) — should not happen under normal operation | "Server Error" |

#### Known limitation: admin login always fails

`IdentityResolverService` resolves `userId`/`adminId` from the account's roles before building the login token. The `ADMIN` side of that resolution (`AdminIdentityLookUpAdapter`) is currently a placeholder with no real admin-provisioning module behind it yet — it unconditionally throws `AdminProvisioningPendingException`. **Any login attempt for an account with the `ADMIN` role will fail with `500` until the admin module is implemented.** This has no workaround on the frontend side; it's a backend gap.

---

## Error body shape

All errors use Spring's `ProblemDetail` (RFC 7807), e.g.:

```json
{
  "type": "about:blank",
  "title": "Conflict Error",
  "status": 409,
  "detail": "Account Already Exists: An account with the email address user@example.com already exists.",
  "instance": "/api/v1/auth/register/user"
}
```

Validation errors additionally include an `errors` property: `{ "field": "message", ... }`.

`GlobalExceptionHandler` maps the domain exception hierarchy to HTTP status as follows:

| Exception | Extends | Status |
|-----------|---------|--------|
| `UnauthorizedException` (incl. `InvalidCredentialsException`) | `DomainException` | 401 |
| `ForbiddenException` (incl. `DisabledAccountException`) | `DomainException` | 403 |
| `ConflictException` (incl. `AccountAlreadyExistsException`) | `DomainException` | 409 |
| `DomainException` (any other) | `FreshKeepException` | 400 |
| `InfrastructureException` (incl. `IdentityMappingException`, `UserProvisioningPendingException`, `AdminProvisioningPendingException`, `InvalidResolvedEntitiesException`) | `FreshKeepException` | 500 |
| `MethodArgumentNotValidException` / `ConstraintViolationException` | — | 400 |
| `HttpMessageNotReadableException` | — | 400 |
| `MethodArgumentTypeMismatchException` | — | 400 |

Note: `UnauthorizedException` and `ForbiddenException` are handled *before* the generic `DomainException` handler, so their subtypes correctly resolve to 401/403 rather than falling through to 400.

---

## Security & access control

Configured in `AppSecurityConfiguration` (`SecurityFilterChain`) and enforced by `JwtAuthenticationFilter` + `@PreAuthorize` (method security is enabled via `@EnableMethodSecurity`).

### Authentication mechanism

- Stateless (`SessionCreationPolicy.STATELESS`), CSRF disabled — this is a pure JWT bearer-token API, no session cookies.
- `JwtAuthenticationFilter` runs on every request, before `UsernamePasswordAuthenticationFilter`:
  - If there is no `Authorization` header, or it doesn't start with `Bearer `, the request proceeds unauthenticated (anonymous) — the filter does **not** reject it itself.
  - If a bearer token is present and valid, it populates the `SecurityContext` with a `CustomUserPrincipal` and its `ROLE_*` authorities extracted from the token's `roles` claim.
  - If the token is present but invalid/expired/unparseable, the filter silently clears the security context and the request continues as anonymous — it does not itself return an error; downstream authorization rules decide the outcome.

### URL-level rules (`authorizeHttpRequests`)

```
/api/v1/auth/register/admin        → hasRole('ADMIN')
/api/v1/auth/**                    → permitAll
anyRequest                         → authenticated
```

The specific `register/admin` matcher is declared *before* the broader `/api/v1/auth/**` matcher, so it's evaluated first and actually takes effect (Spring Security stops at the first matching rule). `register/user` and `login` fall through to the `permitAll` rule.

### Effective access per endpoint

| Endpoint | Filter chain | Method security | Net effect |
|----------|--------------|------------------|------------|
| `POST /register/user` | permitAll | none | Public, no token required |
| `POST /register/admin` | `hasRole('ADMIN')` | `@PreAuthorize("hasRole('ADMIN')")` (redundant, defense in depth) | Requires a valid `Bearer` JWT for an account with role `ADMIN` |
| `POST /login` | permitAll | none | Public, no token required |

### Failure handling for authorization

- `CustomAuthenticationEntryPoint` (triggers on `AuthenticationException`, i.e. no authentication present at all) → **401**, title "Unauthorized", body includes `instance` (request URI).
- `CustomAccessDeniedHandler` (triggers on `AccessDeniedException`, i.e. authenticated but lacking the required role) → **403**, title "Forbidden", body includes `instance` and an `error` property.

For `register/admin` specifically:

- No `Authorization` header, or an invalid/expired/malformed bearer token → no authentication for `@PreAuthorize` to evaluate → **401** via `CustomAuthenticationEntryPoint`.
- Valid bearer token, but the account's role is not `ADMIN` → authenticated but denied → **403** via `CustomAccessDeniedHandler`.

Any other route not matched above (i.e. anything outside `/api/v1/auth/**`) requires a valid, non-anonymous authentication (`anyRequest().authenticated()`); missing/invalid tokens there also produce 401 via the entry point.

---

# Space API Contract

Source: `SpaceController` (`modules/space/infrastructure/web`), `CreateSpaceService`, `Space`/`StorageSpot`/`Emoji` domain
models, `JpaSpaceRepositoryAdapter`.

Base path: `api/v1/spaces`

Requires authentication (see [Security & access control](#security--access-control-1)) — every endpoint below needs a
valid `Bearer` JWT for an account with the `USER` role, obtained via `POST /api/v1/auth/login`.

---

## 1. Create Space

`POST /api/v1/spaces`

### Request body (`CreateSpaceRequest`)

```json
{
  "spaceName": "Kitchen",
  "emoji": "🏠",
  "storageSpots": [
    { "name": "Main Shelf", "type": "SHELF" }
  ]
}
```

| Field | Type | Constraints |
|-------|------|-------------|
| `spaceName` | string | required (`@NotBlank`), max 20 characters |
| `emoji` | string | required (`@NotBlank`), 1–8 characters. Also validated at the domain layer (`Emoji`): must consist only of actual emoji codepoints (letters/digits/plain text are rejected) |
| `storageSpots` | array of `StorageSpotRequest` | required, non-empty (`@NotEmpty`), cascade-validated (`@Valid`) |

`StorageSpotRequest`:

| Field | Type | Constraints |
|-------|------|-------------|
| `name` | string | required (`@NotBlank`), max 30 characters |
| `type` | string | required (`@NotBlank`), must be one of: `FRIDGE`, `FREEZER`, `PANTRY`, `FRUIT_BOWL`, `WINE_CELLAR`, `COUNTERTOP`, `SHELF` |

Two storage spots with the same `name` **and** `type` are rejected (see [error responses](#error-responses-1)) —
same name with a different type, or same type with a different name, is allowed.

`creatorId` is **not** part of the request body — it's resolved server-side from the authenticated principal's
`userId` claim (`@AuthenticationPrincipal(expression = "userId")`), the same claim documented under
[JWT claims](#jwt-claims) above.

### Success response — `201 Created`

`Location` header: `/api/v1/spaces/{id}`

```json
{
  "id": "b3f1c9a0-....",
  "spaceName": "Kitchen",
  "storageSpots": [
    { "storageSpotId": "c4a2d8b1-....", "storageSpotName": "Main Shelf", "storageSpotType": "SHELF" }
  ],
  "creatorId": "d5b3e9c2-....",
  "participantIds": ["d5b3e9c2-...."]
}
```

On creation, `participantIds` always contains exactly the creator's `userId` — there's no way to add other
participants at creation time yet.

⚠️ **The response does not echo back the submitted `emoji`.** `Space`'s `emoji` is persisted, but `SpaceResult`/
`SpaceResponse` currently omit it entirely — the frontend must hold onto the value it submitted locally rather than
expect it back from this endpoint.

### Error responses

| Status | Condition | Body (`ProblemDetail`) title |
|--------|-----------|-------------------------------|
| 400 Bad Request | Any field fails bean validation (`spaceName`/`emoji`/`storageSpots` blank/missing/too long/empty, a storage spot's `name`/`type` blank/too long/not a recognized type) | "Validation Error In Body Data" (+ `errors` map). Nested storage-spot errors use bracketed keys, e.g. `errors["storageSpots[0].name"]` — **not** a nested JSON structure, so client code must access it as a flat map key containing literal `[` `]` characters |
| 400 Bad Request | Malformed/missing JSON body | "Message Not Readable" |
| 400 Bad Request | `spaceName` has no letters, `emoji` fails domain-level emoji validation, a storage spot `name` has no letters, or two storage spots share the same `name`+`type` (`InvalidSpaceNameException` / `InvalidEmojiException` / `InvalidStorageSpotName` / `InvalidSpaceException`) | "Business Rule Error" |
| 401 Unauthorized | No `Authorization` header, or an invalid/malformed/expired bearer token | "Unauthorized" |
| 403 Forbidden | Valid token, but the account does not have the `USER` role | "Forbidden" |
| 500 Internal Server Error | Persistence failure (e.g. DB constraint violation, connection issue) wrapped as `SpacePersistenceException` | "Server Error" |

Note: when a storage spot's `type` is blank, it simultaneously fails both `@NotBlank` and the custom `@EnumValue`
constraint. Since `errors` is a flat map keyed by field name, only one of the two messages survives (whichever
Hibernate Validator evaluates last for that field) — don't rely on the exact wording of that specific message; rely
on the field key (`errors["storageSpots[0].type"]`) being present.

---

## Security & access control {#security--access-control-1}

Enforced via `@PreAuthorize("hasRole('USER')")` on `SpaceController.create` — there is no URL-level rule for
`/api/v1/spaces/**` in `AppSecurityConfiguration`, so it falls under the default `anyRequest().authenticated()` at
the filter-chain level, with the role check happening at the method-security layer.

| Endpoint | Filter chain | Method security | Net effect |
|----------|--------------|------------------|------------|
| `POST /api/v1/spaces` | `authenticated()` | `@PreAuthorize("hasRole('USER')")` | Requires a valid `Bearer` JWT for an account with role `USER` |

Failure handling matches the rest of the API (see [Failure handling for authorization](#failure-handling-for-authorization)):
no/invalid token → 401 via `CustomAuthenticationEntryPoint`; valid token without the `USER` role → 403 via
`CustomAccessDeniedHandler`.
