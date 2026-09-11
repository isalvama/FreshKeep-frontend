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

Source: `SpaceController` (`modules/space/infrastructure/web`), `CreateSpaceService`, `GetSpaceOverviewService`,
`GetStorageSpotsService`, `Space`/`StorageSpot`/`Emoji` domain models, `JpaSpaceRepositoryAdapter`,
`SpaceProductsLookUpPort`/`ProductQueryAdapter` (product-listing lookup, `modules/product`).

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
  "emoji": "🏠",
  "storageSpots": [
    { "storageSpotId": "c4a2d8b1-....", "storageSpotName": "Main Shelf", "storageSpotType": "SHELF" }
  ],
  "creatorId": "d5b3e9c2-....",
  "participantIds": ["d5b3e9c2-...."]
}
```

On creation, `participantIds` always contains exactly the creator's `userId` — there's no way to add other
participants at creation time yet.

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

## 2. Get My Spaces

`GET /api/v1/spaces`

Returns every space where the authenticated user is a participant. Creators are automatically participants (see
[Create Space](#1-create-space)), so this includes spaces the user created as well as ones they were added to.
`creatorId`/participant scoping comes from the JWT's `userId` claim, same as `POST` — there's no request body or
query parameters.

### Success response — `200 OK`

```json
[
  {
    "id": "b3f1c9a0-....",
    "spaceName": "Kitchen",
    "emoji": "🏠",
    "storageSpots": [
      { "storageSpotId": "c4a2d8b1-....", "storageSpotName": "Main Shelf", "storageSpotType": "SHELF" }
    ],
    "creatorId": "d5b3e9c2-....",
    "participantIds": ["d5b3e9c2-...."]
  }
]
```

Returns `200 OK` with an empty array (`[]`) — not an error — when the user is not a participant in any space.

### Error responses

| Status | Condition | Body (`ProblemDetail`) title |
|--------|-----------|-------------------------------|
| 401 Unauthorized | No `Authorization` header, or an invalid/malformed/expired bearer token | "Unauthorized" |
| 403 Forbidden | Valid token, but the account does not have the `USER` role | "Forbidden" |

---

## 3. Get Space Overview

`GET /api/v1/spaces/{spaceId}/overview`

Returns a single space's current name/emoji/storage spots together with every product currently stored in it —
the "what's in this space right now" view, meant to be used right after confirming/reprocessing a receipt, and
whenever the user revisits the space afterward. Unlike the other endpoints in this section, storage spots and
products are looked up live for this one call, not carried over from any earlier request — if a participant renamed
a storage spot or another user added/removed products moments ago, this reflects that immediately.

### Success response — `200 OK`

```json
{
  "id": "b3f1c9a0-....",
  "name": "Kitchen",
  "emoji": "🏠",
  "storageSpots": [
    { "storageSpotId": "c4a2d8b1-....", "storageSpotName": "Fridge", "storageSpotType": "FRIDGE" }
  ],
  "productResults": [
    {
      "id": "e6c4fa03-....",
      "productName": "Milk",
      "expirationDate": "2026-09-15",
      "storageSpotId": "c4a2d8b1-....",
      "productType": "DAIRY",
      "priceAmount": 2.50,
      "currency": "USD"
    }
  ]
}
```

`productResults` is returned sorted by `expirationDate` ascending (soonest-to-expire first) — same convention as
the `confirm`/`reprocess` product lists. A space with no products yet returns `200 OK` with `productResults: []`,
not an error.

### Error responses

| Status | Condition | Body (`ProblemDetail`) title |
|--------|-----------|-------------------------------|
| 400 Bad Request | `spaceId` path variable is not a valid UUID | "Validation Error in Parameter" |
| 400 Bad Request | Space does not exist (`InvalidSpaceReferenceException`) | "Business Rule Error" |
| 401 Unauthorized | No `Authorization` header, or an invalid/malformed/expired bearer token | "Unauthorized" |
| 403 Forbidden | Valid token, but the account does not have the `USER` role | "Forbidden" |
| 409 Conflict | Authenticated user is not a participant of `spaceId` (`SpaceNotAccessibleException`) | "Conflict Error" |

---

## Security & access control {#security--access-control-1}

Enforced via `@PreAuthorize("hasRole('USER')")` on `SpaceController.create`, `SpaceController.getByParticipantId`, and
`SpaceController.getOverView` — there is no URL-level rule for `/api/v1/spaces/**` in `AppSecurityConfiguration`, so it
falls under the default `anyRequest().authenticated()` at the filter-chain level, with the role check happening at the
method-security layer.

| Endpoint | Filter chain | Method security | Net effect |
|----------|--------------|------------------|------------|
| `POST /api/v1/spaces` | `authenticated()` | `@PreAuthorize("hasRole('USER')")` | Requires a valid `Bearer` JWT for an account with role `USER` |
| `GET /api/v1/spaces` | `authenticated()` | `@PreAuthorize("hasRole('USER')")` | Requires a valid `Bearer` JWT for an account with role `USER` |
| `GET /api/v1/spaces/{spaceId}/overview` | `authenticated()` | `@PreAuthorize("hasRole('USER')")` | Requires a valid `Bearer` JWT for an account with role `USER` |

Failure handling matches the rest of the API (see [Failure handling for authorization](#failure-handling-for-authorization)):
no/invalid token → 401 via `CustomAuthenticationEntryPoint`; valid token without the `USER` role → 403 via
`CustomAccessDeniedHandler`.

---

# Shopping Receipt API Contract

Source: `ShoppingReceiptController` (`modules/shopping_receipt/infrastructure/web`), `ProcessNewShoppingReceiptService`,
`ReProcessShoppingReceiptService`, `ConfirmShoppingReceiptService`, `ShoppingReceipt`/`ReceiptImage` domain models,
`GlobalExceptionHandler`.

Base path: `api/v1/spaces/{spaceId}`

Requires authentication — every endpoint below needs a valid `Bearer` JWT for an account with the `USER` role
(`@PreAuthorize("hasRole('USER')")`), same as the [Space API](#space-api-contract). `{spaceId}` in the path must be a
valid UUID; the authenticated user must be a **participant** of that space (see
[shared error responses](#shared-error-responses)).

All three endpoints are steps of one flow: `processNewShoppingReceipt` runs the AI extraction on an uploaded image;
the client then either `confirm`s the extracted data as-is, or `reprocess`es it after the user flags specific
products as wrong. `reprocess` and `confirm` both consume/produce `application/json`; `processNewShoppingReceipt`
consumes `multipart/form-data`.

---

## 1. Process a new Shopping Receipt

`POST /api/v1/spaces/{spaceId}/receipt-images`

Consumes `multipart/form-data`.

### Request (`ProcessNewShoppingReceiptRequest`, bound via `@ModelAttribute`)

| Field      | Type          | Constraints        |
|------------|---------------|---------------------|
| `file`     | file part     | required (`@NotNull`) — the receipt image |
| `language` | string        | required (`@NotBlank`) — see [Language field](#language-field) below |

This step only uploads and AI-extracts the receipt; it does **not** persist a `ShoppingReceipt` or any `Product`s
yet. The uploaded image itself is persisted as a `ReceiptImage` (so its id can be referenced by `reprocess`/`confirm`
without re-uploading), but the extracted data is returned to the client for review, not saved.

### Success response — `201 Created`

`Location` header: `/api/v1/spaces/{spaceId}/receipt-images/{receiptImageId}`

```json
{
  "receiptImageId": "b3f1c9a0-....",
  "suggestedStorageSpots": [
    { "storageSpotId": "c4a2d8b1-....", "storageSpotName": "Fridge", "storageSpotType": "FRIDGE" }
  ],
  "purchaseShoppingDate": "2026-09-08",
  "storeName": "SuperMart",
  "productExtractions": [
    {
      "expirationDate": "2026-09-15",
      "productName": "Milk",
      "suggestedStorageSpotId": "c4a2d8b1-....",
      "productType": "DAIRY",
      "priceAmount": 2.50,
      "currency": "USD"
    }
  ],
  "flaggedProducts": [
    {
      "expirationDate": "2026-09-15",
      "productName": "Milk",
      "suggestedStorageSpotId": "c4a2d8b1-....",
      "productType": "DAIRY",
      "priceAmount": 2.50,
      "currency": "USD"
    }
  ]
}
```

Notes on this shape:

- `productExtractions` is the full list of products the AI extracted; `flaggedProducts` is the **subset** of that
  same list the AI itself flagged as low-confidence/worth reviewing (e.g. bad expiration-date guess) — it is not a
  separate/user-driven list at this stage. Use it to pre-highlight rows for the user to double check before they
  submit `reprocess` or `confirm`.
- `purchaseShoppingDate` is already rectified server-side: if the AI extracted a future date, it's clamped to today
  and every product's `expirationDate` is shifted by the same number of days. Trust this value over whatever the AI
  originally read off the receipt.
- Any product whose AI-suggested storage spot isn't one of this space's actual storage spots is silently
  backfilled with a same-type fallback (or `null` if no matching type exists in the space) — don't expect
  `suggestedStorageSpotId` to always be one of the ids the AI "saw" on the receipt.
- If the AI review step itself is unreachable, `flaggedProducts` degrades to `[]` rather than failing the request —
  the client won't get an error for this, just no flags.
- `productExtractions[].productName`/`flaggedProducts[].productName` (and `errorReason`, if set) are written by the
  AI in the language requested via `language` — see [Language field](#language-field) below.

### Error responses

| Status | Condition | Body title |
|--------|-----------|------------|
| 400 Bad Request | `file` missing, or malformed multipart body | "Validation Error In Body Data" / "Message Not Readable" |
| 400 Bad Request | `file` is present but empty (`InvalidReceiptImageException`) | "Business Rule Error" |
| 400 Bad Request | `spaceId` path variable is not a valid UUID | "Validation Error in Parameter" |
| 400 Bad Request | Space does not exist (`InvalidSpaceReferenceException`) | "Business Rule Error" |
| 400 Bad Request | AI extraction failed in a retryable way after retries exhausted (`AiRetryableException`) | "AI Server Error" |
| 401/403 | Auth failures — see [shared error responses](#shared-error-responses) | — |
| 409 Conflict | Authenticated user is not a participant of `spaceId` (`SpaceNotAccessibleException`) | "Conflict Error" |
| 422 Unprocessable Content | AI could not process the image at all (`AiUnprocessableInputException`) — e.g. not a readable receipt | "Unprocessable Ticket Data Error" |
| 429 Too Many Requests | AI provider rate limit hit (`AiRateLimitedException`) | "AI Rate Limit Exceedance" |
| 500 Internal Server Error | Unexpected AI-side failure (`TicketProcessingException`) | "Internal AI Server Error" |

---

## 2. Reprocess with flagged products

`POST /api/v1/spaces/{spaceId}/shopping-receipt/reprocess`

Use this when the user reviewed the `processNewShoppingReceipt` response and flagged one or more products as wrong
— it re-runs AI extraction (seeded with the full product list **and** the specific ones flagged) against the
already-uploaded receipt image, then **persists** the resulting `ShoppingReceipt` and its `Product`s. This is the
"AI, try again on these" path; use [Confirm](#3-confirm-and-persist) instead when nothing needs re-extraction.

### Request body (`ReProcessShoppingReceiptRequest`)

```json
{
  "receiptImageId": "b3f1c9a0-....",
  "shoppingDate": "2026-09-08",
  "storeName": "SuperMart",
  "language": "es",
  "flaggedProducts": [
    { "expirationDate": "2026-09-15", "productName": "Milk", "suggestedStorageSpotId": "c4a2d8b1-....", "productType": "DAIRY", "priceAmount": 2.50, "currency": "USD" }
  ],
  "allProducts": [
    { "expirationDate": "2026-09-15", "productName": "Milk", "suggestedStorageSpotId": "c4a2d8b1-....", "productType": "DAIRY", "priceAmount": 2.50, "currency": "USD" }
  ]
}
```

| Field             | Type                    | Constraints |
|--------------------|-------------------------|-------------|
| `receiptImageId`  | string (UUID)           | required, must reference a `ReceiptImage` already created via `processNewShoppingReceipt` |
| `shoppingDate`    | string (`yyyy-MM-dd`)   | required, must not be in the future (`@PastOrPresent`, evaluated against the server's system clock) |
| `storeName`       | string                  | required, non-blank |
| `language`        | string                  | required (`@NotBlank`) — see [Language field](#language-field) below |
| `flaggedProducts` | array of `ProductRequest` | required, non-empty — the products the user flagged for re-extraction |
| `allProducts`     | array of `ProductRequest` | required, non-empty — the full current product list (flagged + unflagged), used as context for the AI |

`ProductRequest`:

| Field                    | Type                | Constraints |
|--------------------------|---------------------|-------------|
| `expirationDate`         | string (`yyyy-MM-dd`) | required |
| `productName`            | string              | required, max 30 chars |
| `suggestedStorageSpotId` | string (UUID)       | required |
| `productType`            | string              | required, max 30 chars |
| `priceAmount`            | number              | optional, must be positive if present |
| `currency`               | string              | optional, max 20 chars |

Both `flaggedProducts` and `allProducts` bind via indexed form/query-style keys under the hood
(`@ModelAttribute`), e.g. `allProducts[0].productName=Milk` — send them as a normal JSON array in the request body;
Spring handles the binding.

### Success response — `201 Created`

`Location` header: `/api/v1/spaces/{spaceId}/shopping-receipt/{shoppingReceiptId}`

```json
{
  "id": "d5b3e9c2-....",
  "shoppingDate": "2026-09-08",
  "storeName": "SuperMart",
  "products": [
    {
      "id": "e6c4fa03-....",
      "productName": "Milk",
      "expirationDate": "2026-09-15",
      "storageSpotId": "c4a2d8b1-....",
      "productType": "DAIRY",
      "priceAmount": 2.50,
      "currency": "USD"
    }
  ],
  "storageSpots": [
    { "storageSpotId": "c4a2d8b1-....", "storageSpotName": "Fridge", "storageSpotType": "FRIDGE" }
  ]
}
```

Unlike step 1, `products[].id` here is a real persisted `Product` id — this response reflects what was actually
saved, not a re-extraction preview. `products[].productName` for any re-examined (flagged) product is written in
the language requested via `language`; unflagged products keep whatever language they already had from the prior
`processNewShoppingReceipt`/`reprocess` call, since they're carried over unchanged rather than re-extracted.

`products` is returned sorted by `expirationDate` ascending (soonest-to-expire first), nulls last — the sort only
affects response order, not persistence order.

### Error responses

| Status | Condition | Body title |
|--------|-----------|------------|
| 400 Bad Request | Any field fails bean validation (missing/blank/empty/future date/etc.) | "Validation Error In Body Data" |
| 400 Bad Request | Malformed/missing JSON body | "Message Not Readable" |
| 400 Bad Request | `spaceId`/`receiptImageId` not a valid UUID | "Validation Error in Parameter" / field error |
| 400 Bad Request | Space does not exist (`InvalidSpaceReferenceException`) | "Business Rule Error" |
| 400 Bad Request | `receiptImageId` does not reference an existing `ReceiptImage` (`NonExistentReceiptImageException`) | "Business Rule Error" |
| 400 Bad Request | Rectified `shoppingDate` still ends up after today, e.g. from clock skew (`InvalidShoppingReceiptException`) | "Business Rule Error" |
| 400 Bad Request | AI extraction failed in a retryable way after retries exhausted (`AiRetryableException`) | "AI Server Error" |
| 401/403 | Auth failures — see [shared error responses](#shared-error-responses) | — |
| 409 Conflict | Authenticated user is not a participant of `spaceId` (`SpaceNotAccessibleException`) | "Conflict Error" |
| 422 Unprocessable Content | AI could not process the image at all (`AiUnprocessableInputException`) | "Unprocessable Ticket Data Error" |
| 429 Too Many Requests | AI provider rate limit hit (`AiRateLimitedException`) | "AI Rate Limit Exceedance" |
| 500 Internal Server Error | Unexpected AI-side failure (`TicketProcessingException`) | "Internal AI Server Error" |

Note: unlike `processNewShoppingReceipt`, this endpoint has **no fallback** if the AI call fails outright — since its
whole purpose is re-extraction, an AI failure here surfaces as a real error to the client rather than degrading
silently.

---

## Language field {#language-field}

`processNewShoppingReceipt` and `reprocess` both take a `language` field, used to instruct the AI to write
`productName` (and `errorReason`, if set) in that language rather than whatever language the receipt itself is in.

- Send the **language subtag only** — e.g. `"es"`, not `"es-AR"`. On Flutter, that's
  `WidgetsBinding.instance.platformDispatcher.locale.languageCode`, not `.toLanguageTag()`.
- Matching is case-insensitive.
- Currently recognized values: `en` (English), `es` (Spanish), `ca` (Catalan), `fr` (French), `de` (German),
  `pt` (Portuguese), `it` (Italian).
- `language` is required at the request level (`@NotBlank` — a missing field is a `400`), but an unrecognized value
  is **not** an error: the backend silently falls back to English rather than rejecting the request, since the
  device can legitimately report a language the app doesn't support yet. Don't rely on validating this value against
  the list above client-side beyond keeping the user's actual device language — send whatever `languageCode` you
  get and let the backend degrade gracefully.
- `confirm` has no `language` field — it never calls the AI, so there's nothing to translate.

---

## 3. Confirm and persist

`POST /api/v1/spaces/{spaceId}/shopping-receipt/confirm`

Use this when the user reviewed the `processNewShoppingReceipt` response and everything looked correct — it skips
AI re-extraction entirely and persists the client-submitted data as-is (after backfilling any invalid storage-spot
suggestions, same as the other two endpoints).

### Request body (`ConfirmShoppingReceiptRequest`)

Same shape as reprocess, **minus** `flaggedProducts`:

```json
{
  "receiptImageId": "b3f1c9a0-....",
  "shoppingDate": "2026-09-08",
  "storeName": "SuperMart",
  "allProducts": [
    { "expirationDate": "2026-09-15", "productName": "Milk", "suggestedStorageSpotId": "c4a2d8b1-....", "productType": "DAIRY", "priceAmount": 2.50, "currency": "USD" }
  ]
}
```

| Field            | Type                       | Constraints |
|-------------------|----------------------------|-------------|
| `receiptImageId` | string (UUID)              | required, must reference a `ReceiptImage` already created via `processNewShoppingReceipt` |
| `shoppingDate`   | string (`yyyy-MM-dd`)      | required, must not be in the future (`@PastOrPresent`) |
| `storeName`      | string                     | required, non-blank |
| `allProducts`    | array of `ProductRequest`  | required, non-empty — see `ProductRequest` shape under [Reprocess](#2-reprocess-with-flagged-products) |

### Success response — `201 Created`

Same `ShoppingReceiptResponse` shape as [Reprocess](#2-reprocess-with-flagged-products), `Location` header:
`/api/v1/spaces/{spaceId}/shopping-receipt/{shoppingReceiptId}`.

Unlike reprocess, `shoppingDate`/`storeName`/product fields here are **not** run through AI re-extraction or date
rectification before persisting — they're saved exactly as submitted (storage-spot fallback resolution still
applies). If `shoppingDate` is in the future, `ShoppingReceipt.create()`'s own domain validation rejects it (see
error table below) rather than silently clamping it, unlike step 1's preview response.

As with reprocess, `products` is returned sorted by `expirationDate` ascending (soonest-to-expire first), nulls
last.

### Error responses

| Status | Condition | Body title |
|--------|-----------|------------|
| 400 Bad Request | Any field fails bean validation (missing/blank/empty/future date/etc.) | "Validation Error In Body Data" |
| 400 Bad Request | Malformed/missing JSON body | "Message Not Readable" |
| 400 Bad Request | `spaceId`/`receiptImageId` not a valid UUID | "Validation Error in Parameter" / field error |
| 400 Bad Request | Space does not exist (`InvalidSpaceReferenceException`) | "Business Rule Error" |
| 400 Bad Request | `receiptImageId` does not reference an existing `ReceiptImage` (`NonExistentReceiptImageException`) | "Business Rule Error" |
| 400 Bad Request | `shoppingDate` is after the server's current date (`InvalidShoppingReceiptException`) | "Business Rule Error" |
| 401/403 | Auth failures — see [shared error responses](#shared-error-responses) | — |
| 409 Conflict | Authenticated user is not a participant of `spaceId` (`SpaceNotAccessibleException`) | "Conflict Error" |

---

## Shared error responses

These apply to all three endpoints above, in addition to each endpoint's own table:

| Status | Condition | Body title |
|--------|-----------|------------|
| 401 Unauthorized | No `Authorization` header, or an invalid/malformed/expired bearer token | "Unauthorized" |
| 403 Forbidden | Valid token, but the account does not have the `USER` role | "Forbidden" |

Enforced the same way as the rest of the API — see [Security & access control](#security--access-control) and
[Failure handling for authorization](#failure-handling-for-authorization).

Error body shape (RFC 7807 `ProblemDetail`) is identical to the rest of the API — see
[Error body shape](#error-body-shape).
