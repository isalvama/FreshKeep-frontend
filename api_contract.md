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
4. **The JWT `roles` claim carries the `ROLE_` prefix** — e.g. `["ROLE_USER"]`, not `["USER"]` (see [JWT claims](#jwt-claims)). Client-side role checks against decoded tokens must account for the prefix (the backend strips it again when parsing incoming tokens).
5. **The receipt flow now runs on a server-side draft `ShoppingReceipt`.** `processNewShoppingReceipt` returns a `shoppingReceiptId` (first field of its response) that `reprocess`/`confirm` must send back as a required field, and every product submitted to `reprocess`/`confirm` must carry a `manuallyEditedExpirationDate` boolean — see the [Shopping Receipt API Contract](#shopping-receipt-api-contract).

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
| `roles` | string[] | e.g. `["ROLE_USER"]`, **with** the `ROLE_` prefix — the token generator prefixes every role with `ROLE_` (`JwtTokenGeneratorAdapter`); the backend strips it again when parsing incoming tokens, but clients decoding the claim see the prefixed values |
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
| `InfrastructureException` (incl. `IdentityMappingException`, `UserProvisioningPendingException`, `AdminProvisioningPendingException`, `InvalidResolvedEntitiesException`, `ExpirationDateCalculationException`) | `FreshKeepException` | 500 |
| `ApplicationException` (incl. `MoveProductDataUnavailableException`) | `RuntimeException` (handled explicitly, title "Application Server Error") | 500 |
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
`GetStorageSpotsService`, `CreateSpaceInvitationService`, `JoinSpaceByInvitationService`,
`Space`/`StorageSpot`/`Emoji`/`SpaceInvitation` domain models, `JpaSpaceRepositoryAdapter`,
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

## 4. Create invitation

`POST /api/v1/spaces/{spaceId}/invitations`

No request body. Generates an invitation token for the space. Tokens are valid for **24 hours** from creation and
have **no usage-count limit** during that window — any number of different users can join with the same token before
it expires (there is currently no per-invitation use cap and no deactivation on use; only expiry turns it inactive).

`creatorId` is resolved server-side from the authenticated principal's `userId` claim, same as
[Create Space](#1-create-space) — the caller must already be a participant of `spaceId`.

### Success response — `201 Created`

`Location` header: `/api/v1/spaces/{spaceId}/invitations/{id}`

```json
{
  "id": "a7c1e5f3-....",
  "token": "the-invitation-token",
  "spaceId": "b3f1c9a0-....",
  "userCreatorId": "d5b3e9c2-....",
  "expiresAt": "2026-09-29T21:00:00",
  "isActive": true
}
```

`expiresAt` is a server-local `LocalDateTime` serialized without an offset — it is computed from the server's UTC
clock (creation time + 24h). `isActive` is `true` on creation and stays `true` as the token is used.

### Error responses

| Status | Condition | Body (`ProblemDetail`) title |
|--------|-----------|-------------------------------|
| 400 Bad Request | `spaceId` path variable is not a valid UUID | "Validation Error in Parameter" |
| 401 Unauthorized | No `Authorization` header, or an invalid/malformed/expired bearer token | "Unauthorized" |
| 403 Forbidden | Valid token, but the account does not have the `USER` role | "Forbidden" |
| 409 Conflict | Authenticated user is not a participant of `spaceId` (`SpaceNotAccessibleException`) | "Conflict Error" |

---

## 5. Join space by invitation

`POST /api/v1/spaces/invitations/{token}/join`

No request body. Adds the authenticated user as a participant of the invitation's space. The token's use counter is
incremented and the participant is added atomically.

### Success response — `200 OK`

```json
{ "spaceId": "b3f1c9a0-...." }
```

### Error responses

| Status | Condition | Body (`ProblemDetail`) title |
|--------|-----------|-------------------------------|
| 400 Bad Request | `token` does not reference an existing invitation (`NonExistentSpaceInvitationException`) | "Business Rule Error" |
| 400 Bad Request | Invitation has expired, is no longer active, or has reached its usage limit (`ExpiredSpaceInvitationException` — expiry is the only reachable cause today, since created invitations have no use cap) | "Business Rule Error" |
| 401 Unauthorized | No `Authorization` header, or an invalid/malformed/expired bearer token | "Unauthorized" |
| 403 Forbidden | Valid token, but the account does not have the `USER` role | "Forbidden" |
| 409 Conflict | Authenticated user is already a participant of the space (`SpaceNotAccessibleException`) | "Conflict Error" |

---

## Security & access control {#security--access-control-1}

Enforced via `@PreAuthorize("hasRole('USER')")` on `SpaceController.create`, `SpaceController.getByParticipantId`,
`SpaceController.getOverView`, `SpaceController.createInvitation`, and `SpaceController.useInvitation` — there is no
URL-level rule for `/api/v1/spaces/**` in `AppSecurityConfiguration`, so it
falls under the default `anyRequest().authenticated()` at the filter-chain level, with the role check happening at the
method-security layer.

| Endpoint | Filter chain | Method security | Net effect |
|----------|--------------|------------------|------------|
| `POST /api/v1/spaces` | `authenticated()` | `@PreAuthorize("hasRole('USER')")` | Requires a valid `Bearer` JWT for an account with role `USER` |
| `GET /api/v1/spaces` | `authenticated()` | `@PreAuthorize("hasRole('USER')")` | Requires a valid `Bearer` JWT for an account with role `USER` |
| `GET /api/v1/spaces/{spaceId}/overview` | `authenticated()` | `@PreAuthorize("hasRole('USER')")` | Requires a valid `Bearer` JWT for an account with role `USER` |
| `POST /api/v1/spaces/{spaceId}/invitations` | `authenticated()` | `@PreAuthorize("hasRole('USER')")` | Requires a valid `Bearer` JWT for an account with role `USER` |
| `POST /api/v1/spaces/invitations/{token}/join` | `authenticated()` | `@PreAuthorize("hasRole('USER')")` | Requires a valid `Bearer` JWT for an account with role `USER` |

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

All three endpoints are steps of one flow: `processNewShoppingReceipt` runs the AI extraction on an uploaded image
and persists a **draft** `ShoppingReceipt` (returning its `shoppingReceiptId`); the client then either `confirm`s
the extracted data as-is, or `reprocess`es it after the user flags specific products as wrong — both must reference
the draft via `shoppingReceiptId`, and it's at that step that the receipt is finalized and its `Product`s are
actually persisted. `reprocess` and `confirm` both consume/produce `application/json`; `processNewShoppingReceipt`
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

This step uploads and AI-extracts the receipt, persisting two things: the uploaded image as a `ReceiptImage`, and a
**draft** `ShoppingReceipt` carrying the extracted `purchaseShoppingDate`/`storeName`. No `Product`s are persisted
yet — the extracted data is returned to the client for review, and the draft's `shoppingReceiptId` (first field of
the response) is what `reprocess`/`confirm` must send back to finalize the receipt.

### Success response — `201 Created`

`Location` header: `/api/v1/spaces/{spaceId}/receipt-images/{receiptImageId}`

```json
{
  "shoppingReceiptId": "a8d2f0e1-....",
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
already-uploaded receipt image, then finalizes the draft `ShoppingReceipt` and persists it with its `Product`s. This
is the "AI, try again on these" path; use [Confirm](#3-confirm-and-persist) instead when nothing needs re-extraction.

### Request body (`ReProcessShoppingReceiptRequest`)

```json
{
  "shoppingReceiptId": "a8d2f0e1-....",
  "receiptImageId": "b3f1c9a0-....",
  "shoppingDate": "2026-09-08",
  "storeName": "SuperMart",
  "language": "es",
  "flaggedProducts": [
    { "expirationDate": "2026-09-15", "productName": "Milk", "suggestedStorageSpotId": "c4a2d8b1-....", "productType": "DAIRY", "priceAmount": 2.50, "currency": "USD", "manuallyEditedExpirationDate": false }
  ],
  "allProducts": [
    { "expirationDate": "2026-09-15", "productName": "Milk", "suggestedStorageSpotId": "c4a2d8b1-....", "productType": "DAIRY", "priceAmount": 2.50, "currency": "USD", "manuallyEditedExpirationDate": false }
  ]
}
```

| Field                | Type                    | Constraints |
|----------------------|-------------------------|-------------|
| `shoppingReceiptId`  | string (UUID)           | required — must reference the **draft** `ShoppingReceipt` created by `processNewShoppingReceipt` for this same `receiptImageId`/`spaceId`/creator; the draft is finalized by this call |
| `receiptImageId`     | string (UUID)           | required, must reference the `ReceiptImage` created via `processNewShoppingReceipt` (must belong to the same draft) |
| `shoppingDate`       | string (`yyyy-MM-dd`)   | required, must not be in the future (`@PastOrPresent`, evaluated against the server's system clock) |
| `storeName`          | string                  | required, non-blank |
| `language`           | string                  | required (`@NotBlank`) — see [Language field](#language-field) below |
| `flaggedProducts`    | array of `ProductRequest` | required, non-empty — the products the user flagged for re-extraction |
| `allProducts`        | array of `ProductRequest` | required, non-empty — the full current product list (flagged + unflagged), used as context for the AI |

`ProductRequest`:

| Field                          | Type                | Constraints |
|--------------------------------|---------------------|-------------|
| `expirationDate`               | string (`yyyy-MM-dd`) | required |
| `productName`                  | string              | required, max 30 chars |
| `suggestedStorageSpotId`        | string (UUID)       | required |
| `productType`                  | string              | required, max 30 chars |
| `priceAmount`                  | number              | optional, must be positive if present |
| `currency`                     | string              | optional, max 20 chars |
| `manuallyEditedExpirationDate` | boolean             | **required on every product** (`@NotNull`) — `true` when the user hand-edited that product's expiration date. Only consumed by `confirm` (it exempts such products from purchase-date-shift rectification, see [Confirm and persist](#3-confirm-and-persist)); `reprocess` currently ignores its value but still requires it present |

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
| 400 Bad Request | Any field fails bean validation (missing/blank/empty/future date/etc., incl. a missing `manuallyEditedExpirationDate` on any product) | "Validation Error In Body Data" |
| 400 Bad Request | Malformed/missing JSON body | "Message Not Readable" |
| 400 Bad Request | `spaceId`/`receiptImageId`/`shoppingReceiptId` not a valid UUID | "Validation Error in Parameter" / field error |
| 400 Bad Request | Space does not exist (`InvalidSpaceReferenceException`) | "Business Rule Error" |
| 400 Bad Request | `receiptImageId` does not reference an existing `ReceiptImage` (`NonExistentReceiptImageException`) | "Business Rule Error" |
| 400 Bad Request | `shoppingReceiptId` does not reference an existing `ShoppingReceipt` (`NonExistentShoppingReceiptException`) | "Business Rule Error" |
| 400 Bad Request | `shoppingReceiptId`/`receiptImageId`/`spaceId`/creator don't all belong to the same draft (`InvalidShoppingReceiptException` — "cannot be reprocessed in the requested context") | "Business Rule Error" |
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
AI re-extraction entirely and persists the client-submitted data (after backfilling any invalid storage-spot
suggestions, same as the other two endpoints — see the rectification note below).

### Request body (`ConfirmShoppingReceiptRequest`)

Same shape as reprocess, **minus** `flaggedProducts` and `language`:

```json
{
  "shoppingReceiptId": "a8d2f0e1-....",
  "receiptImageId": "b3f1c9a0-....",
  "shoppingDate": "2026-09-08",
  "storeName": "SuperMart",
  "allProducts": [
    { "expirationDate": "2026-09-15", "productName": "Milk", "suggestedStorageSpotId": "c4a2d8b1-....", "productType": "DAIRY", "priceAmount": 2.50, "currency": "USD", "manuallyEditedExpirationDate": false }
  ]
}
```

| Field                | Type                       | Constraints |
|-----------------------|----------------------------|-------------|
| `shoppingReceiptId`  | string (UUID)              | required — must reference the **draft** `ShoppingReceipt` created by `processNewShoppingReceipt` for this same `receiptImageId`/`spaceId`/creator; the draft is finalized by this call |
| `receiptImageId`     | string (UUID)              | required, must reference a `ReceiptImage` already created via `processNewShoppingReceipt` (must belong to the same draft) |
| `shoppingDate`       | string (`yyyy-MM-dd`)      | required, must not be in the future (`@PastOrPresent`) |
| `storeName`          | string                     | required, non-blank |
| `allProducts`        | array of `ProductRequest`  | required, non-empty — see `ProductRequest` shape under [Reprocess](#2-reprocess-with-flagged-products) (incl. the required `manuallyEditedExpirationDate`) |

### Success response — `201 Created`

Same `ShoppingReceiptResponse` shape as [Reprocess](#2-reprocess-with-flagged-products), `Location` header:
`/api/v1/spaces/{spaceId}/shopping-receipt/{shoppingReceiptId}`.

Unlike reprocess, `shoppingDate`/`storeName`/product fields here are **not** run through AI re-extraction before
persisting, and there is no future-date clamping — a `shoppingDate` in the future is rejected with a `400`
(`@PastOrPresent` bean validation), unlike step 1's preview response which silently clamps. One rectification
**does** still apply: if the submitted `shoppingDate` differs from the draft's extracted `purchaseShoppingDate`, the
`expirationDate` of every product with `manuallyEditedExpirationDate: false` is shifted by the same number of days
(preserving the extracted shelf-life relative to the new purchase date); products with
`manuallyEditedExpirationDate: true` are saved exactly as submitted. Storage-spot fallback resolution applies to all
products, as in the other endpoints.

As with reprocess, `products` is returned sorted by `expirationDate` ascending (soonest-to-expire first), nulls
last.

### Error responses

| Status | Condition | Body title |
|--------|-----------|------------|
| 400 Bad Request | Any field fails bean validation (missing/blank/empty/future date/etc., incl. a missing `manuallyEditedExpirationDate` on any product) | "Validation Error In Body Data" |
| 400 Bad Request | Malformed/missing JSON body | "Message Not Readable" |
| 400 Bad Request | `spaceId`/`receiptImageId`/`shoppingReceiptId` not a valid UUID | "Validation Error in Parameter" / field error |
| 400 Bad Request | Space does not exist (`InvalidSpaceReferenceException`) | "Business Rule Error" |
| 400 Bad Request | `receiptImageId` does not reference an existing `ReceiptImage` (`NonExistentReceiptImageException`) | "Business Rule Error" |
| 400 Bad Request | `shoppingReceiptId` does not reference an existing `ShoppingReceipt` (`NonExistentShoppingReceiptException`) | "Business Rule Error" |
| 400 Bad Request | `shoppingReceiptId`/`receiptImageId`/`spaceId`/creator don't all belong to the same draft (`InvalidShoppingReceiptException` — "cannot be confirmed in the requested context") | "Business Rule Error" |
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

---

# Product API Contract

Source: `ProductController` (`modules/product/infrastructure/web`), `DeleteProductService`, `DeleteProductsService`,
`MoveProductService`, `UpdateProductService`, `Product` domain model,
`ProductMovedExpirationDateCalculatorPort`/`OllamaProductMovedExpirationDateCalculatorAdapter` (expiration-date
recalculation on move).

Base path: `api/v1/products`

Requires authentication — every endpoint needs a valid `Bearer` JWT for an account with the `USER` role
(`@PreAuthorize("hasRole('USER')")`), same as the [Space API](#space-api-contract). The authenticated user must be a
**participant** of the space where the target product is stored (`SpaceNotAccessibleException` → 409 otherwise).

All of these operate on products created through the receipt flow ([Confirm and persist](#3-confirm-and-persist) /
[Reprocess](#2-reprocess-with-flagged-products)) — there is no direct product-creation endpoint.

---

## 1. Update a product

`PATCH /api/v1/products/{id}`

Partial update — every field is optional; omitted/`null` fields keep their current value (an empty body `{}` is a
valid no-op that returns the product's current state).

### Request body (`UpdateProductRequest`)

| Field            | Type                  | Constraints |
|------------------|-----------------------|-------------|
| `name`           | string                | optional, max 30 chars, must contain a non-space character (`@Pattern`) |
| `expirationDate` | string (`yyyy-MM-dd`) | optional |
| `productType`    | string                | optional, max 30 chars — must be a valid `ProductType` constant name, checked at the domain layer: an invalid value is a 400 "Business Rule Error" (`InvalidProductTypeException`), not a bean-validation `errors` entry |
| `amount`         | number                | optional, positive if present (the product's price amount) |
| `currency`       | string                | optional, max 20 chars — must be a valid currency constant name, checked at the domain layer (`InvalidCurrencyException` → 400 "Business Rule Error") |

### Success response — `200 OK`

```json
{
  "productId": "e6c4fa03-....",
  "name": "Milk",
  "expirationDate": "2026-09-15",
  "productType": "DAIRY",
  "amount": 2.50,
  "currency": "USD"
}
```

### Error responses

| Status | Condition | Body title |
|--------|-----------|------------|
| 400 Bad Request | Field fails bean validation (too long / spaces-only / non-positive amount) | "Validation Error In Body Data" |
| 400 Bad Request | `id` path variable is not a valid UUID | "Validation Error in Parameter" |
| 400 Bad Request | Product does not exist (`NonExistentProductException`) | "Business Rule Error" |
| 400 Bad Request | `productType`/`currency` not a recognized constant (`InvalidProductTypeException`/`InvalidCurrencyException`) | "Business Rule Error" |
| 401 Unauthorized | No `Authorization` header, or an invalid/malformed/expired bearer token | "Unauthorized" |
| 403 Forbidden | Valid token, but the account does not have the `USER` role | "Forbidden" |
| 409 Conflict | User is not a participant of the product's storage spot's space (`SpaceNotAccessibleException`) | "Conflict Error" |

---

## 2. Move a product

`PATCH /api/v1/products/{id}/storage-spot`

Moves the product to a new storage spot (both spots' spaces must be accessible to the user). As part of the move, the
product's `expirationDate` is **recalculated by an AI (Ollama) call** seeded with the product's storage-spot history —
the returned `newExpirationDate` may differ from the product's previous date. This call needs the backend's Ollama
service to be reachable; AI-side failures surface as real errors (this endpoint has no silent fallback).

### Request body (`MoveProductRequest`)

| Field               | Type            | Constraints |
|---------------------|-----------------|-------------|
| `oldStorageSpotId`  | string (UUID)   | required — must match the product's **current** storage spot (`InvalidProductMoveException` → 400 otherwise, despite the exception's "same spot" wording) |
| `newStorageSpotId`  | string (UUID)   | required — the destination spot |

### Success response — `200 OK`

```json
{
  "productId": "e6c4fa03-....",
  "newStorageSpotId": "c4a2d8b1-....",
  "newExpirationDate": "2026-09-18"
}
```

### Error responses

| Status | Condition | Body title |
|--------|-----------|------------|
| 400 Bad Request | `oldStorageSpotId`/`newStorageSpotId` missing, or `id` path variable not a valid UUID | "Validation Error In Body Data" / "Validation Error in Parameter" |
| 400 Bad Request | Product does not exist (`NonExistentProductException`) | "Business Rule Error" |
| 400 Bad Request | `oldStorageSpotId` doesn't match the product's current spot (`InvalidProductMoveException`) | "Business Rule Error" |
| 400 Bad Request | AI recalculation failed in a retryable way after retries exhausted (`AiRetryableException`) | "AI Server Error" |
| 401 Unauthorized | No `Authorization` header, or an invalid/malformed/expired bearer token | "Unauthorized" |
| 403 Forbidden | Valid token, but the account does not have the `USER` role | "Forbidden" |
| 409 Conflict | User is not a participant of the old/new spot's space(s) (`SpaceNotAccessibleException`) | "Conflict Error" |
| 500 Internal Server Error | Bad/missing data for the recalculation (`ExpirationDateCalculationException`) | "Server Error" |
| 500 Internal Server Error | Supporting data (shopping date / storage-spot history / spot info) couldn't be resolved (`MoveProductDataUnavailableException`) | "Application Server Error" |

---

## 3. Delete a product

`DELETE /api/v1/products/{id}`

**Soft delete** — sets the product's `deletedAt` timestamp rather than removing the row. Returns `204 No Content`
with no body.

### Error responses

| Status | Condition | Body title |
|--------|-----------|------------|
| 400 Bad Request | `id` path variable is not a valid UUID | "Validation Error in Parameter" |
| 400 Bad Request | Product does not exist (`NonExistentProductException`) | "Business Rule Error" |
| 401 Unauthorized | No `Authorization` header, or an invalid/malformed/expired bearer token | "Unauthorized" |
| 403 Forbidden | Valid token, but the account does not have the `USER` role | "Forbidden" |
| 409 Conflict | User is not a participant of the product's storage spot's space (`SpaceNotAccessibleException`) | "Conflict Error" |

---

## 4. Delete multiple products

`DELETE /api/v1/products`

Batch version of the single delete — same soft-delete semantics. All-or-nothing per product: a missing id or a
product stored in a space the user can't access fails the whole request (nothing is deleted).

### Request body (`DeleteProductsRequest`)

```json
{ "productsIds": ["e6c4fa03-....", "f7b5d2e4-...."] }
```

| Field          | Type             | Constraints |
|----------------|------------------|-------------|
| `productsIds`  | array of UUIDs   | required, non-empty |

### Success response — `204 No Content` (no body)

### Error responses

Same as the single delete, plus:

| Status | Condition | Body title |
|--------|-----------|------------|
| 400 Bad Request | `productsIds` missing/empty | "Validation Error In Body Data" |
| 400 Bad Request | Any element is not a valid UUID | "Message Not Readable" |

---

## Security & access control {#security--access-control-2}

Same pattern as the [Space API](#security--access-control-1): no URL-level rule for `/api/v1/products/**` in
`AppSecurityConfiguration` — everything falls under the default `anyRequest().authenticated()`, with
`@PreAuthorize("hasRole('USER')")` on every `ProductController` method.

Failure handling matches the rest of the API: no/invalid token → 401 via `CustomAuthenticationEntryPoint`; valid
token without the `USER` role → 403 via `CustomAccessDeniedHandler`.

---

# Admin API Contract

Source: `AdminController` (`modules/admin/infrastructure/web`), `GetUsersUseCase`,
`GetProductsUseCase`, `GetShoppingReceiptsUseCase`, and `AdminResponseMapper`.

Base path: `api/v1/admin`

All Admin endpoints require a valid JWT for an account with the `ADMIN` role. Requests without a valid admin token
receive `401 Unauthorized` or `403 Forbidden` according to the shared security rules above.

## User endpoints

### Daily user registration metrics

`GET /api/v1/admin/metrics/users/registrations`

Required query parameters:

| Parameter | Type | Constraints |
|-----------|------|-------------|
| `from` | date (`yyyy-MM-dd`) | required |
| `to` | date (`yyyy-MM-dd`) | required; range must be 0–100 days |

Response — `200 OK`:

```json
[
  { "date": "2026-01-10", "count": 4 }
]
```

### Registered users

`GET /api/v1/admin/users`

Required query parameters:

| Parameter | Type | Constraints |
|-----------|------|-------------|
| `from` | date (`yyyy-MM-dd`) | required |
| `to` | date (`yyyy-MM-dd`) | required; range must be 0–90 days |
| `page` | integer | one-based; defaults to `1` |
| `size` | integer | defaults to `30`, maximum `40` |

Response — `200 OK`:

```json
{
  "content": [
    {
      "id": "b3f1c9a0-....",
      "email": "user@example.com",
      "username": "fresh-user",
      "registeredAt": "2026-01-10T10:00:00Z",
      "lastLoggedAt": null
    }
  ],
  "page": 1,
  "size": 30,
  "totalElements": 1,
  "totalPages": 1
}
```

### User details

`GET /api/v1/admin/users/{id}`

Response — `200 OK`:

```json
{
  "id": "b3f1c9a0-....",
  "email": "user@example.com",
  "username": "fresh-user",
  "registeredAt": "2026-01-10T10:00:00Z",
  "lastLoggedAt": null,
  "roles": ["USER"],
  "spaces": [
    { "id": "c4a2d8b1-....", "name": "Kitchen" }
  ],
  "receipts": [
    {
      "id": "d5b3e9c2-....",
      "createdAt": "2026-01-10T10:00:00Z",
      "purchaseDate": "2026-01-10",
      "storeName": "SuperMart"
    }
  ]
}
```

## Product endpoints

### Daily product metrics

`GET /api/v1/admin/metrics/products`

Required query parameters:

| Parameter | Type | Constraints |
|-----------|------|-------------|
| `from` | date (`yyyy-MM-dd`) | required |
| `to` | date (`yyyy-MM-dd`) | required; range must be 0–100 days |

Optional query parameters:

| Parameter | Type |
|-----------|------|
| `spaceId` | UUID |
| `creatorId` | UUID |

Response — `200 OK`:

```json
[
  { "date": "2026-03-10", "count": 5 }
]
```

### Products

`GET /api/v1/admin/products`

Optional query parameters:

| Parameter | Type | Default/constraints |
|-----------|------|---------------------|
| `sort` | enum | product sort default |
| `page` | integer | defaults to `0` |
| `size` | integer | defaults to `30`, maximum `40` |
| `productType` | enum | valid `ProductType` value |
| `creatorId` | UUID | optional |
| `shoppingReceiptId` | UUID | optional |
| `isDeleted` | boolean | accepted by the request model; currently not applied by the product query |

Response — `200 OK`:

```json
[
  {
    "id": "e6c4fa03-....",
    "name": "Milk",
    "expirationDate": "2026-09-15",
    "actualStorageSpotId": "c4a2d8b1-....",
    "productType": "DAIRY",
    "shoppingReceiptId": "d5b3e9c2-....",
    "price": 2.50,
    "currency": "USD"
  }
]
```

### Product details

`GET /api/v1/admin/products/{id}`

Response — `200 OK`:

```json
{
  "id": "e6c4fa03-....",
  "name": "Milk",
  "productType": "DAIRY",
  "expirationDate": "2026-09-15",
  "actualStorageSpotId": "c4a2d8b1-....",
  "storageSpotIdType": "FRIDGE",
  "creatorId": "b3f1c9a0-....",
  "creatorUsername": "fresh-user",
  "creatorEmail": "user@example.com",
  "spaceId": "c4a2d8b1-....",
  "spaceName": "Kitchen",
  "storeName": "SuperMart",
  "purchaseDate": "2026-09-08",
  "createdAt": "2026-09-08T10:00:00Z",
  "shoppingReceiptId": "d5b3e9c2-....",
  "price": 2.50,
  "currency": "USD"
}
```

### Product types

`GET /api/v1/admin/product-types`

Response — `200 OK`:

```json
[
  { "productType": "DAIRY", "productCount": 12 },
  { "productType": "FRUITS", "productCount": 8 }
]
```

## Shopping receipt endpoints

### Daily shopping receipt metrics

`GET /api/v1/admin/metrics/shopping-receipts`

Required query parameters:

| Parameter | Type | Constraints |
|-----------|------|-------------|
| `from` | date (`yyyy-MM-dd`) | required |
| `to` | date (`yyyy-MM-dd`) | required; range must be 0–100 days |

Optional query parameters: `spaceId` and `creatorId` (UUID).

Response — `200 OK`:

```json
[
  { "date": "2026-04-10", "totalReceipts": 3 }
]
```

### Shopping receipts

`GET /api/v1/admin/shopping-receipts`

Required query parameters:

| Parameter | Type | Constraints |
|-----------|------|-------------|
| `from` | date (`yyyy-MM-dd`) | required |
| `to` | date (`yyyy-MM-dd`) | required; range must be 0–100 days |

Optional query parameters: `spaceId` and `userId` (UUID).

Response — `200 OK`:

```json
[
  {
    "id": "d5b3e9c2-....",
    "creatorId": "b3f1c9a0-....",
    "spaceId": "c4a2d8b1-....",
    "storeName": "SuperMart",
    "purchaseDate": "2026-09-08",
    "createdAt": "2026-09-08T10:00:00Z"
  }
]
```

### Shopping receipt details

`GET /api/v1/admin/shopping-receipts/{id}`

Response — `200 OK`:

```json
{
  "id": "d5b3e9c2-....",
  "creatorId": "b3f1c9a0-....",
  "creatorUsername": "fresh-user",
  "creatorEmail": "user@example.com",
  "spaceId": "c4a2d8b1-....",
  "spaceName": "Kitchen",
  "storeName": "SuperMart",
  "purchaseDate": "2026-09-08",
  "createdAt": "2026-09-08T10:00:00Z",
  "receiptImageId": "f7a5d1e4-....",
  "receiptImageAssetId": "shopping_receipts/receipts/abc123",
  "receiptImageMimeType": "image/jpeg",
  "products": [
    {
      "id": "e6c4fa03-....",
      "name": "Milk",
      "expirationDate": "2026-09-15",
      "actualStorageSpotId": "c4a2d8b1-....",
      "productType": "DAIRY",
      "price": 2.50,
      "currency": "USD"
    }
  ]
}
```

### Admin error responses

| Status | Condition |
|--------|-----------|
| 400 Bad Request | Invalid date, UUID, enum, pagination, or filter value |
| 401 Unauthorized | Missing or invalid bearer token |
| 403 Forbidden | Authenticated user does not have the `ADMIN` role |
| 400 Bad Request | Requested user, product, or shopping receipt does not exist (mapped as a domain/business-rule error) |

Errors use the shared RFC 7807 `ProblemDetail` format documented above.
