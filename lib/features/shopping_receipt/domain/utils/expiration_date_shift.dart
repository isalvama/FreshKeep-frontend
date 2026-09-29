/// Mirrors the backend's confirm rectification: shifts [original] by the
/// number of calendar days between [fromShoppingDate] and [toShoppingDate].
///
/// See "Confirm and persist" in `api_contract.md`: when the submitted
/// `shoppingDate` differs from the draft's extracted `purchaseShoppingDate`,
/// the backend shifts every product with `manuallyEditedExpirationDate: false`
/// by the same number of days. Used only for the on-screen preview — requests
/// always send the original extracted dates.
///
/// Day counts are computed on UTC dates and the result is built with
/// `DateTime(y, m, d + delta)`, so DST changes can't shift it by an hour.
DateTime shiftExpirationDate({
  required DateTime original,
  required DateTime fromShoppingDate,
  required DateTime toShoppingDate,
}) {
  final delta = _utcDate(
    toShoppingDate,
  ).difference(_utcDate(fromShoppingDate)).inDays;
  return DateTime(original.year, original.month, original.day + delta);
}

DateTime _utcDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);
