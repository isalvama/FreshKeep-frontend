sealed class AuthFailure {
  final String message;

  const AuthFailure(this.message);
}

class ValidationFailure extends AuthFailure {
  const ValidationFailure(super.message); // 400
}

class ConflictFailure extends AuthFailure {
  const ConflictFailure(super.message); // 409 — register only
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure(super.message); // 401 — login only
}

class AccountDisabledFailure extends AuthFailure {
  const AccountDisabledFailure(super.message); // 403 — login only
}

class ServerFailure extends AuthFailure {
  const ServerFailure(super.message); // 500
}

class NetworkFailure extends AuthFailure {
  const NetworkFailure(super.message); // no connectivity / timeout
}

sealed class SpaceFailure {
  final String message;

  const SpaceFailure(this.message);
}

class SpaceValidationFailure extends SpaceFailure {
  const SpaceValidationFailure(super.message); // 400 (field or business-rule)
}

class SpaceUnauthorizedFailure extends SpaceFailure {
  const SpaceUnauthorizedFailure(super.message); // 401
}

class SpaceForbiddenFailure extends SpaceFailure {
  const SpaceForbiddenFailure(super.message); // 403
}

class SpaceServerFailure extends SpaceFailure {
  const SpaceServerFailure(super.message); // 500
}

class SpaceNetworkFailure extends SpaceFailure {
  const SpaceNetworkFailure(super.message); // no connectivity / timeout
}

sealed class ShoppingReceiptFailure {
  final String message;

  const ShoppingReceiptFailure(this.message);
}

class ShoppingReceiptValidationFailure extends ShoppingReceiptFailure {
  const ShoppingReceiptValidationFailure(super.message); // 400
}

class ShoppingReceiptUnauthorizedFailure extends ShoppingReceiptFailure {
  const ShoppingReceiptUnauthorizedFailure(super.message); // 401
}

class ShoppingReceiptForbiddenFailure extends ShoppingReceiptFailure {
  const ShoppingReceiptForbiddenFailure(super.message); // 403
}

class ShoppingReceiptConflictFailure extends ShoppingReceiptFailure {
  const ShoppingReceiptConflictFailure(super.message); // 409 — not a participant
}

class ShoppingReceiptUnprocessableFailure extends ShoppingReceiptFailure {
  const ShoppingReceiptUnprocessableFailure(super.message); // 422 — unreadable image
}

class ShoppingReceiptRateLimitedFailure extends ShoppingReceiptFailure {
  const ShoppingReceiptRateLimitedFailure(super.message); // 429
}

class ShoppingReceiptServerFailure extends ShoppingReceiptFailure {
  const ShoppingReceiptServerFailure(super.message); // 500
}

class ShoppingReceiptNetworkFailure extends ShoppingReceiptFailure {
  const ShoppingReceiptNetworkFailure(super.message); // no connectivity / timeout
}

sealed class SpaceOverviewFailure {
  final String message;

  const SpaceOverviewFailure(this.message);
}

class SpaceOverviewValidationFailure extends SpaceOverviewFailure {
  const SpaceOverviewValidationFailure(super.message); // 400
}

class SpaceOverviewUnauthorizedFailure extends SpaceOverviewFailure {
  const SpaceOverviewUnauthorizedFailure(super.message); // 401
}

class SpaceOverviewForbiddenFailure extends SpaceOverviewFailure {
  const SpaceOverviewForbiddenFailure(super.message); // 403
}

class SpaceOverviewConflictFailure extends SpaceOverviewFailure {
  const SpaceOverviewConflictFailure(super.message); // 409 — not a participant
}

class SpaceOverviewNetworkFailure extends SpaceOverviewFailure {
  const SpaceOverviewNetworkFailure(super.message); // no connectivity / timeout
}

sealed class ProductFailure {
  final String message;

  const ProductFailure(this.message);
}

class ProductValidationFailure extends ProductFailure {
  const ProductValidationFailure(super.message); // 400 — missing product
}

class ProductUnauthorizedFailure extends ProductFailure {
  const ProductUnauthorizedFailure(super.message); // 401
}

class ProductForbiddenFailure extends ProductFailure {
  const ProductForbiddenFailure(super.message); // 403
}

class ProductConflictFailure extends ProductFailure {
  const ProductConflictFailure(super.message); // 409 — not a participant
}

class ProductServerFailure extends ProductFailure {
  const ProductServerFailure(super.message); // 500
}

class ProductNetworkFailure extends ProductFailure {
  const ProductNetworkFailure(super.message); // no connectivity / timeout
}
