# Auth API Contract

Source: `AuthController` (`modules/account/infrastructure/web`), `AppSecurityConfiguration`,
`SpringSecurityConfiguration`, `GlobalExceptionHandler`, `JwtAuthenticationFilter`.

Base path: `api/v1/auth`

All three endpoints consume/produce `application/json`.

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
  "email": "user@example.com",
  "jwtString": "eyJhbGciOi...",
  "expiresIn": 3600000
}
```

`expiresIn` is the raw `jwt.expiration` value (milliseconds) used to build the token, not a computed remaining time.

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

### Access control

Enforced both at the filter-chain level (`/api/v1/auth/register/admin` → `hasRole('ADMIN')`) and via `@PreAuthorize("hasRole('ADMIN')")` on `AuthController.registerAdmin`. A caller must already be authenticated **as an ADMIN** (valid `Bearer` JWT with the `ADMIN` role) to reach this endpoint.

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

Login also updates the account's `lastLogIn` timestamp as a side effect (`accountRepositoryPort.updateLastLogIn`).

### Error responses

| Status | Condition | Body title |
|--------|-----------|------------|
| 400 Bad Request | `email`/`password` fail bean validation | "Validation Error In Body Data" |
| 400 Bad Request | Malformed/missing JSON body | "Message Not Readable" |
| 401 Unauthorized | Wrong email or password (`InvalidCredentialsException`, thrown by `AuthenticationAdapter` for any `AuthenticationException`, e.g. `BadCredentialsException`/unknown user) | "Unauthorized Error" |
| 403 Forbidden | Account exists but is disabled (`DisabledAccountException`, from Spring Security's `DisabledException`) | "Forbidden Request" |
| 500 Internal Server Error | Authentication succeeded but the principal couldn't be mapped (`IdentityMappingException`) | "Server Error" |

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
| `InfrastructureException` (incl. `IdentityMappingException`) | `FreshKeepException` | 500 |
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

- No `Authorization` header, or an invalid/expired/malformed bearer token → the filter chain's `hasRole('ADMIN')` check has no authentication to evaluate → **401** via `CustomAuthenticationEntryPoint`.
- Valid bearer token, but the account's role is not `ADMIN` → authenticated but denied → **403** via `CustomAccessDeniedHandler`.

Any other route not matched above (i.e. anything outside `/api/v1/auth/**`) requires a valid, non-anonymous authentication (`anyRequest().authenticated()`); missing/invalid tokens there also produce 401 via the entry point.
